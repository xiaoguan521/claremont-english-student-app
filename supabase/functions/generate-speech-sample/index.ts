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

type CachedSpeechAsset = {
  bytes: Uint8Array
  mimeType: string
  storagePath: string
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

function extensionForResponseFormat(value: string | null | undefined) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'wav':
      return 'wav'
    case 'ogg':
      return 'ogg'
    case 'flac':
      return 'flac'
    case 'aac':
      return 'aac'
    case 'm4a':
      return 'm4a'
    case 'mp3':
    default:
      return 'mp3'
  }
}

function normalizeMimeType(value: string | null | undefined, fallbackExt: string) {
  const trimmed = value?.trim().toLowerCase()
  if (trimmed && trimmed.startsWith('audio/')) {
    return trimmed
  }

  return `audio/${fallbackExt}`
}

async function sha256Hex(value: string) {
  const bytes = new TextEncoder().encode(value)
  const digest = await crypto.subtle.digest('SHA-256', bytes)
  return Array.from(new Uint8Array(digest))
    .map((item) => item.toString(16).padStart(2, '0'))
    .join('')
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
    bytes: buffer,
    mimeType: contentType,
  }
}

async function resolveCachedSpeech(options: {
  adminClient: ReturnType<typeof createClient>
  schoolId: string
  config: SchoolSpeechConfigRecord
  text: string
}) {
  const extension = extensionForResponseFormat(options.config.response_format)
  const cacheKey = await sha256Hex(
    [
      options.schoolId,
      options.config.provider_type,
      options.config.base_url,
      options.config.model,
      options.config.voice_preset ?? '',
      extension,
      options.text,
    ].join('::'),
  )
  const storagePath = `${options.schoolId}/ai-generated-speech/${cacheKey}.${extension}`

  const signedResult = await options.adminClient.storage
    .from('reference-audio')
    .createSignedUrl(storagePath, 60)

  if (signedResult.data?.signedUrl) {
    const cachedResponse = await fetch(signedResult.data.signedUrl).catch(() => null)
    if (cachedResponse?.ok) {
      const mimeType = normalizeMimeType(
        cachedResponse.headers.get('content-type'),
        extension,
      )
      const bytes = new Uint8Array(await cachedResponse.arrayBuffer())

      return {
        cached: true,
        asset: {
          bytes,
          mimeType,
          storagePath,
        } satisfies CachedSpeechAsset,
      }
    }
  }

  if (signedResult.error &&
      !signedResult.error.message.toLowerCase().includes('not found') &&
      !signedResult.error.message.toLowerCase().includes('object not found')) {
    throw new Error(signedResult.error.message)
  }

  {
    return {
      cached: false,
      storagePath,
      extension,
    }
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

    const cache = await resolveCachedSpeech({
      adminClient,
      schoolId,
      config,
      text,
    })

    let asset: CachedSpeechAsset
    let cached = cache.cached

    if (cache.cached) {
      asset = cache.asset
    } else {
      const result = await synthesizeSpeech({
        config,
        apiKey,
        text,
      })
      const contentType = normalizeMimeType(result.mimeType, cache.extension)
      const uploadResult = await adminClient.storage
        .from('reference-audio')
        .upload(cache.storagePath, result.bytes, {
          upsert: true,
          contentType,
        })

      if (uploadResult.error) {
        throw new Error(uploadResult.error.message)
      }

      asset = {
        bytes: result.bytes,
        mimeType: contentType,
        storagePath: cache.storagePath,
      }
      cached = false
    }

    return json({
      status: 'completed',
      cached,
      audioBase64: encodeBase64(asset.bytes),
      mimeType: asset.mimeType,
      storagePath: `reference-audio:${asset.storagePath}`,
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
