import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
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
  const queueSecret = Deno.env.get('AI_REVIEW_QUEUE_SECRET') ?? ''
  const authHeader = req.headers.get('Authorization')

  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey || !queueSecret.trim()) {
    return json({ error: 'Queue scheduling secrets are not configured.' }, 500)
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

  const { data: operatorMembership, error: membershipError } = await userClient
    .from('memberships')
    .select('id')
    .eq('user_id', user.id)
    .eq('role', 'school_admin')
    .eq('status', 'active')
    .limit(1)
    .maybeSingle()

  if (membershipError || !operatorMembership) {
    return json({ error: 'Current user is not allowed to schedule the AI worker.' }, 403)
  }

  const { error: scheduleError } = await adminClient.rpc(
    'schedule_ai_review_queue_worker',
    {
      project_url: supabaseUrl,
      queue_secret: queueSecret,
    },
  )

  if (scheduleError) {
    return json({ error: scheduleError.message }, 400)
  }

  return json({
    status: 'scheduled',
    message: 'AI 评审队列 worker 已注册为每分钟执行一次。',
  })
})
