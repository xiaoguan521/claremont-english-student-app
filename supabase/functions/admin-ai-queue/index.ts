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

type ProcessQueuePayload = {
  action: 'process_queue'
  batchSize?: number
}

type ScheduleWorkerPayload = {
  action: 'schedule_worker'
}

type RetryFailedPayload = {
  action: 'retry_failed_reviews'
  schoolId: string
  assignmentId?: string
  runNow?: boolean
  batchSize?: number
}

type QueueActionPayload =
  | ProcessQueuePayload
  | ScheduleWorkerPayload
  | RetryFailedPayload

async function invokeQueueWorker(options: {
  supabaseUrl: string
  publishableKey: string
  queueSecret: string
  batchSize: number
}) {
  const response = await fetch(`${options.supabaseUrl}/functions/v1/ai-review-submission`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: options.publishableKey,
      'x-queue-secret': options.queueSecret,
    },
    body: JSON.stringify({
      action: 'process_queue',
      batchSize: options.batchSize,
    }),
  })

  const data = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error(
      typeof data?.error === 'string'
        ? data.error
        : `Queue worker returned ${response.status}.`,
    )
  }

  return data
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

  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
    return json({ error: 'Supabase environment is not configured.' }, 500)
  }

  if (!queueSecret.trim()) {
    return json({ error: 'Queue worker secret is not configured.' }, 500)
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

  const { data: activeMemberships, error: membershipError } = await userClient
    .from('memberships')
    .select('school_id')
    .eq('user_id', user.id)
    .eq('role', 'school_admin')
    .eq('status', 'active')

  if (membershipError || !(activeMemberships?.length)) {
    return json({ error: 'Current user is not allowed to manage the AI queue.' }, 403)
  }

  const schoolIds = new Set(
    (activeMemberships ?? [])
      .map((item) => (item as { school_id?: string | null }).school_id)
      .filter((value): value is string => typeof value === 'string' && value.length > 0),
  )

  try {
    const payload = (await req.json()) as QueueActionPayload

    if (payload.action === 'process_queue') {
      const result = await invokeQueueWorker({
        supabaseUrl,
        publishableKey: supabaseAnonKey,
        queueSecret,
        batchSize: Math.min(10, Math.max(1, payload.batchSize ?? 3)),
      })

      return json({
        status: 'processed',
        result,
      })
    }

    if (payload.action === 'schedule_worker') {
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
    }

    if (!payload.schoolId?.trim() || !schoolIds.has(payload.schoolId)) {
      return json({ error: 'Current user cannot manage this school queue.' }, 403)
    }

    if (payload.assignmentId?.trim()) {
      const { data: assignmentRow, error: assignmentError } = await adminClient
        .from('assignments')
        .select('id')
        .eq('id', payload.assignmentId)
        .eq('school_id', payload.schoolId)
        .maybeSingle()

      if (assignmentError || !assignmentRow) {
        return json({ error: 'Assignment not found in the current school.' }, 404)
      }
    }

    const assignmentQuery = adminClient
      .from('assignments')
      .select('id')
      .eq('school_id', payload.schoolId)

    if (payload.assignmentId?.trim()) {
      assignmentQuery.eq('id', payload.assignmentId)
    }

    const { data: assignmentRows, error: assignmentRowsError } = await assignmentQuery

    if (assignmentRowsError) {
      return json({ error: assignmentRowsError.message }, 400)
    }

    const assignmentIds = (assignmentRows ?? [])
      .map((item) => (item as { id?: string | null }).id)
      .filter((value): value is string => typeof value === 'string' && value.length > 0)

    if (assignmentIds.length === 0) {
      return json({
        status: 'idle',
        retriedCount: 0,
        message: '当前范围内没有可重新排队的作业。',
      })
    }

    const { data: submissionRows, error: submissionRowsError } = await adminClient
      .from('submissions')
      .select('id')
      .in('assignment_id', assignmentIds)

    if (submissionRowsError) {
      return json({ error: submissionRowsError.message }, 400)
    }

    const submissionIds = (submissionRows ?? [])
      .map((item) => (item as { id?: string | null }).id)
      .filter((value): value is string => typeof value === 'string' && value.length > 0)

    if (submissionIds.length === 0) {
      return json({
        status: 'idle',
        retriedCount: 0,
        message: '当前范围内还没有学生提交，不需要重排 AI 初评。',
      })
    }

    const { data: failedJobs, error: failedJobsError } = await adminClient
      .from('evaluation_jobs')
      .select('id')
      .eq('status', 'failed')
      .in('submission_id', submissionIds)

    if (failedJobsError) {
      return json({ error: failedJobsError.message }, 400)
    }

    const jobIds = (failedJobs ?? [])
      .map((item) => (item as { id?: string | null }).id)
      .filter((value): value is string => typeof value === 'string' && value.length > 0)

    if (jobIds.length === 0) {
      return json({
        status: 'idle',
        retriedCount: 0,
        message: '当前范围内没有 AI 初评失败记录。',
      })
    }

    const retryAt = new Date().toISOString()
    const { error: retryError } = await adminClient
      .from('evaluation_jobs')
      .update({
        status: 'retrying',
        last_error: null,
        started_at: null,
        completed_at: null,
        updated_at: retryAt,
      })
      .in('id', jobIds)

    if (retryError) {
      return json({ error: retryError.message }, 400)
    }

    let queueResult: unknown = null
    if (payload.runNow === true) {
      queueResult = await invokeQueueWorker({
        supabaseUrl,
        publishableKey: supabaseAnonKey,
        queueSecret,
        batchSize: Math.min(10, Math.max(1, payload.batchSize ?? 3)),
      })
    }

    return json({
      status: 'queued',
      retriedCount: jobIds.length,
      queueResult,
      message: `已把 ${jobIds.length} 条 AI 失败记录重新加入队列。`,
    })
  } catch (error) {
    return json(
      {
        error: error instanceof Error ? error.message : 'Unexpected queue management error.',
      },
      500,
    )
  }
})
