import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type GetConfigPayload = {
  action: 'get_config'
  schoolId: string
}

type UpsertConfigPayload = {
  action: 'upsert_config'
  schoolId: string
  providerType: string
  providerLabel: string
  baseUrl: string
  model: string
  apiKey?: string
  enabled: boolean
}

type AiConfigPayload = GetConfigPayload | UpsertConfigPayload

type SchoolAiConfigRecord = {
  school_id: string
  provider_type: string
  provider_label: string
  base_url: string
  model: string
  api_key_masked: string
  api_key_ciphertext: string
  enabled: boolean
  updated_at: string | null
}

type SchoolAiConfigUpsertRecord = {
  school_id: string
  provider_type: string
  provider_label: string
  base_url: string
  model: string
  api_key_ciphertext: string
  api_key_masked: string
  enabled: boolean
  updated_by: string
  created_by?: string
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

function normalizeBaseUrl(value: string) {
  return value.trim().replace(/\/+$/, '')
}

function maskApiKey(value: string) {
  const trimmed = value.trim()
  if (trimmed.length <= 4) {
    return '••••'
  }

  return `••••${trimmed.slice(-4)}`
}

function encodeBase64(bytes: Uint8Array) {
  return btoa(String.fromCharCode(...bytes))
}

async function deriveEncryptionKey(secret: string) {
  const secretBytes = new TextEncoder().encode(secret)
  const digest = await crypto.subtle.digest('SHA-256', secretBytes)

  return crypto.subtle.importKey('raw', digest, { name: 'AES-GCM' }, false, ['encrypt'])
}

async function encryptApiKey(secret: string, apiKey: string) {
  const iv = crypto.getRandomValues(new Uint8Array(12))
  const cryptoKey = await deriveEncryptionKey(secret)
  const encoded = new TextEncoder().encode(apiKey)
  const cipherBuffer = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, cryptoKey, encoded)

  return `${encodeBase64(iv)}:${encodeBase64(new Uint8Array(cipherBuffer))}`
}

function formatConfig(record: SchoolAiConfigRecord | null) {
  if (!record) {
    return null
  }

  return {
    schoolId: record.school_id,
    providerType: record.provider_type,
    providerLabel: record.provider_label,
    baseUrl: record.base_url,
    model: record.model,
    enabled: record.enabled,
    apiKeyConfigured: Boolean(record.api_key_ciphertext),
    apiKeyMasked: record.api_key_masked ?? null,
    updatedAt: record.updated_at,
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

  const payload = (await req.json()) as AiConfigPayload
  if (!payload.schoolId?.trim() || !payload.action) {
    return json({ error: 'Missing required fields.' }, 400)
  }

  const { data: operatorMembership, error: membershipError } = await userClient
    .from('memberships')
    .select('id')
    .eq('user_id', user.id)
    .eq('school_id', payload.schoolId)
    .eq('role', 'school_admin')
    .eq('status', 'active')
    .maybeSingle()

  if (membershipError || !operatorMembership) {
    return json({ error: 'Current user is not allowed to manage this school.' }, 403)
  }

  if (payload.action === 'get_config') {
    const { data, error } = await adminClient
      .from('school_ai_configs')
      .select(
        'school_id, provider_type, provider_label, base_url, model, api_key_masked, api_key_ciphertext, enabled, updated_at',
      )
      .eq('school_id', payload.schoolId)
      .maybeSingle()

    if (error) {
      return json({ error: error.message }, 400)
    }

    return json({
      config: formatConfig((data as SchoolAiConfigRecord | null) ?? null),
    })
  }

  const providerType = payload.providerType?.trim()
  const providerLabel = payload.providerLabel?.trim()
  const baseUrl = normalizeBaseUrl(payload.baseUrl ?? '')
  const model = payload.model?.trim()
  const nextApiKey = payload.apiKey?.trim() ?? ''

  if (!providerType || !providerLabel || !baseUrl || !model) {
    return json({ error: 'Provider type, label, base URL and model are required.' }, 400)
  }

  let parsedUrl: URL
  try {
    parsedUrl = new URL(baseUrl)
  } catch {
    return json({ error: 'Base URL is not a valid URL.' }, 400)
  }

  if (!['http:', 'https:'].includes(parsedUrl.protocol)) {
    return json({ error: 'Base URL must start with http:// or https://.' }, 400)
  }

  const { data: existingRecord, error: existingError } = await adminClient
    .from('school_ai_configs')
    .select(
      'school_id, provider_type, provider_label, base_url, model, api_key_masked, api_key_ciphertext, enabled, updated_at',
    )
    .eq('school_id', payload.schoolId)
    .maybeSingle()

  if (existingError) {
    return json({ error: existingError.message }, 400)
  }

  let apiKeyCiphertext = (existingRecord as SchoolAiConfigRecord | null)?.api_key_ciphertext ?? ''
  let apiKeyMasked = (existingRecord as SchoolAiConfigRecord | null)?.api_key_masked ?? ''

  if (nextApiKey) {
    if (!encryptionSecret.trim()) {
      return json({ error: 'AI encryption secret is not configured.' }, 500)
    }

    apiKeyCiphertext = await encryptApiKey(encryptionSecret, nextApiKey)
    apiKeyMasked = maskApiKey(nextApiKey)
  } else if (!apiKeyCiphertext) {
    return json({ error: 'Please provide an API key for the first save.' }, 400)
  }

  const upsertPayload: SchoolAiConfigUpsertRecord = {
    school_id: payload.schoolId,
    provider_type: providerType,
    provider_label: providerLabel,
    base_url: baseUrl,
    model,
    api_key_ciphertext: apiKeyCiphertext,
    api_key_masked: apiKeyMasked,
    enabled: payload.enabled,
    updated_by: user.id,
  }

  if (!(existingRecord as SchoolAiConfigRecord | null)?.school_id) {
    upsertPayload.created_by = user.id
  }

  const { data: savedConfig, error: saveError } = await adminClient
    .from('school_ai_configs')
    .upsert(upsertPayload, { onConflict: 'school_id' })
    .select(
      'school_id, provider_type, provider_label, base_url, model, api_key_masked, api_key_ciphertext, enabled, updated_at',
    )
    .single()

  if (saveError) {
    return json({ error: saveError.message }, 400)
  }

  return json({
    config: formatConfig(savedConfig as SchoolAiConfigRecord),
  })
})
