import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type ResetPasswordPayload = {
  action: 'reset_password'
  schoolId: string
  userId: string
  temporaryPassword: string
}

type SetMembershipStatusPayload = {
  action: 'set_membership_status'
  schoolId: string
  membershipId: string
  nextStatus: 'active' | 'disabled'
}

type ReassignMembershipClassPayload = {
  action: 'reassign_membership_class'
  schoolId: string
  membershipId: string
  classId: string | null
}

type ManageUserPayload =
  | ResetPasswordPayload
  | SetMembershipStatusPayload
  | ReassignMembershipClassPayload

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

  const payload = (await req.json()) as ManageUserPayload
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

  if (payload.action === 'reset_password') {
    if (!payload.userId?.trim() || !payload.temporaryPassword?.trim()) {
      return json({ error: 'Reset password action requires user and temporary password.' }, 400)
    }

    const { data: scopedMembership, error: scopedMembershipError } = await userClient
      .from('memberships')
      .select('id')
      .eq('school_id', payload.schoolId)
      .eq('user_id', payload.userId)
      .maybeSingle()

    if (scopedMembershipError || !scopedMembership) {
      return json({ error: 'Target user is not in the selected school.' }, 400)
    }

    const { error: resetError } = await adminClient.auth.admin.updateUserById(payload.userId, {
      password: payload.temporaryPassword,
    })

    if (resetError) {
      return json({ error: resetError.message }, 400)
    }

    return json({
      action: payload.action,
      userId: payload.userId,
      temporaryPassword: payload.temporaryPassword,
    })
  }

  if (payload.action === 'reassign_membership_class') {
    if (!payload.membershipId?.trim()) {
      return json({ error: 'Class assignment action requires membership id.' }, 400)
    }

    const { data: targetMembership, error: targetMembershipError } = await adminClient
      .from('memberships')
      .select('id, role, school_id, class_id')
      .eq('id', payload.membershipId)
      .eq('school_id', payload.schoolId)
      .single()

    if (targetMembershipError || !targetMembership) {
      return json({ error: 'Target membership does not exist in the selected school.' }, 400)
    }

    if (!['teacher', 'student'].includes(targetMembership.role)) {
      return json({ error: 'Only teacher and student memberships can be reassigned.' }, 400)
    }

    if (payload.classId) {
      const { data: targetClass, error: targetClassError } = await adminClient
        .from('classes')
        .select('id')
        .eq('id', payload.classId)
        .eq('school_id', payload.schoolId)
        .single()

      if (targetClassError || !targetClass) {
        return json({ error: 'Target class does not exist in the selected school.' }, 400)
      }
    }

    const { data: updatedMembership, error: updateClassError } = await adminClient
      .from('memberships')
      .update({ class_id: payload.classId })
      .eq('id', payload.membershipId)
      .eq('school_id', payload.schoolId)
      .select('id, class_id, role')
      .single()

    if (updateClassError) {
      return json({ error: updateClassError.message }, 400)
    }

    return json({
      action: payload.action,
      membershipId: updatedMembership.id,
      classId: updatedMembership.class_id,
      role: updatedMembership.role,
    })
  }

  if (!payload.membershipId?.trim()) {
    return json({ error: 'Membership status action requires membership id.' }, 400)
  }

  const { data: scopedMembership, error: scopedMembershipError } = await adminClient
    .from('memberships')
    .select('id, status')
    .eq('id', payload.membershipId)
    .eq('school_id', payload.schoolId)
    .maybeSingle()

  if (scopedMembershipError || !scopedMembership) {
    return json({ error: 'Target membership does not exist in the selected school.' }, 400)
  }

  const { data: updatedMembership, error: updateError } = await adminClient
    .from('memberships')
    .update({ status: payload.nextStatus })
    .eq('id', payload.membershipId)
    .eq('school_id', payload.schoolId)
    .select('id, status')
    .single()

  if (updateError) {
    return json({ error: updateError.message }, 400)
  }

  return json({
    action: payload.action,
    membershipId: updatedMembership.id,
    status: updatedMembership.status,
  })
})
