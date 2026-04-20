import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type SpeechRequestPayload = {
  schoolId: string
  text: string
}

type SchoolSpeechConfigRecord = {
  school_id: string
  provider_type: string
  provider_label: string
  base_url: string
  model: string
  voice_preset: string | null
  response_format: string
  api_key_ciphertext: string | null
  enabled: boolean
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  })
}

function decodeBase64(value: string) {
  return Uint8Array.from(atob(value), (char) => char.charCodeAt(0))
}

function encodeBase64(bytes: Uint8Array) {
  return btoa(String.fromCharCode(...bytes))
}

async function deriveEncryptionKey(secret: string) {
  const secretBytes = new TextEncoder().encode(secret)
  const digest = await crypto.subtle.digest('SHA-256', secretBytes)

  return crypto.subtle.importKey('raw', digest, { name: 'AES-GCM' }, false, ['decrypt'])
}

async function decryptApiKey(secret: string, ciphertext: string) {
  const [ivBase64, payloadBase64] = ciphertext.split(':')
  if (!ivBase64 || !payloadBase64) {
    throw new Error('Stored API key ciphertext is invalid.')
  }

  const cryptoKey = await deriveEncryptionKey(secret)
  const decrypted = await crypto.subtle.decrypt(
    {
      name: 'AES-GCM',
      iv: decodeBase64(ivBase64),
    },
    cryptoKey,
    decodeBase64(payloadBase64),
  )

  return new TextDecoder().decode(decrypted)
}

function normalizeBaseUrl(value: string) {
  return value.trim().replace(/\/+$/, '')
}

async function fetchSpeechConfig(
  adminClient: ReturnType<typeof createClient>,
  schoolId: string,
) {
  const { data, error } = await adminClient
    .from('school_speech_configs')
    .select(
      'school_id, provider_type, provider_label, base_url, model, voice_preset, response_format, api_key_ciphertext, enabled',
    )
    .eq('school_id', schoolId)
    .maybeSingle()

  if (error) {
    throw new Error(error.message)
  }

  return (data as SchoolSpeechConfigRecord | null) ?? null
}

async function synthesizeSpeech(options: {
  config: SchoolSpeechConfigRecord
  apiKey: string | null
  text: string
}) {
  const requestBody: Record<string, unknown> = {
    model: options.config.model,
    input: options.text,
    response_format: options.config.response_format || 'mp3',
  }

  if ((options.config.voice_preset ?? '').trim().isNotEmpty) {
    requestBody.voice = options.config.voice_preset?.trim()
  }

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  }

  if ((options.apiKey ?? '').trim().isNotEmpty) {
    headers.Authorization = `Bearer ${options.apiKey}`
  }

  const response = await fetch(`${normalizeBaseUrl(options.config.base_url)}/audio/speech`, {
    method: 'POST',
    headers,
    body: JSON.stringify(requestBody),
    signal: AbortSignal.timeout(45000),
  })

  if (!response.ok) {
    throw new Error(`Speech generation failed. ${response.status} ${await response.text()}`)
  }

  const buffer = new Uint8Array(await response.arrayBuffer())
  const contentType =
    response.headers.get('content-type') ||
    `audio/${(options.config.response_format || 'mp3').toLowerCase()}`

  return {
    audioBase64: encodeBase64(buffer),
    mimeType: contentType,
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed.' }, 405)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const encryptionSecret = Deno.env.get('AI_CONFIG_ENCRYPTION_KEY') ?? ''
  const authHeader = req.headers.get('Authorization')

  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
    return json({ error: 'Supabase function secrets are not configured.' }, 500)
  }

  if (!authHeader) {
    return json({ error: 'Missing authorization header.' }, 401)
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: {
        Authorization: authHeader,
      },
    },
  })

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  })

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser()

  if (userError || !user) {
    return json({ error: 'Unable to validate current user.' }, 401)
  }

  try {
    const payload = (await req.json()) as SpeechRequestPayload
    const schoolId = payload.schoolId?.trim()
    const text = payload.text?.trim()

    if (!schoolId || !text) {
      return json({ error: 'schoolId and text are required.' }, 400)
    }

    const { data: membership, error: membershipError } = await userClient
      .from('memberships')
      .select('id')
      .eq('user_id', user.id)
      .eq('school_id', schoolId)
      .eq('status', 'active')
      .maybeSingle()

    if (membershipError || !membership) {
      return json({ error: 'Current user is not allowed to use this school speech config.' }, 403)
    }

    const config = await fetchSpeechConfig(adminClient, schoolId)
    if (!config || !config.enabled) {
      return json({ error: 'School speech config is missing or disabled.' }, 400)
    }

    const apiKey = config.api_key_ciphertext
      ? await decryptApiKey(encryptionSecret, config.api_key_ciphertext)
      : null

    const result = await synthesizeSpeech({
      config,
      apiKey,
      text,
    })

    return json({
      status: 'completed',
      audioBase64: result.audioBase64,
      mimeType: result.mimeType,
      providerLabel: config.provider_label,
      model: config.model,
    })
  } catch (error) {
    console.error('generate-speech-sample failed', error)
    return json(
      {
        error: error instanceof Error ? error.message : 'Unexpected speech generation error.',
      },
      500,
    )
  }
})
