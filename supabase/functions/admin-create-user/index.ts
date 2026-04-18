import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type CreateUserPayload = {
  email: string
  password: string
  displayName: string
  phone?: string | null
  schoolId: string
  role: 'school_admin' | 'teacher' | 'student'
  classId?: string | null
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

  const payload = (await req.json()) as CreateUserPayload
  if (
    !payload.email?.trim() ||
    !payload.password?.trim() ||
    !payload.displayName?.trim() ||
    !payload.schoolId?.trim() ||
    !payload.role
  ) {
    return json({ error: 'Missing required fields.' }, 400)
  }

  if (payload.role === 'student' && !payload.classId) {
    return json({ error: 'Student accounts must be assigned to a class.' }, 400)
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

  if (payload.classId) {
    const { data: scopedClass, error: classError } = await userClient
      .from('classes')
      .select('id, school_id')
      .eq('id', payload.classId)
      .maybeSingle()

    if (classError || !scopedClass || scopedClass.school_id !== payload.schoolId) {
      return json({ error: 'Class is invalid for the selected school.' }, 400)
    }
  }

  const { data: createdUser, error: createUserError } =
    await adminClient.auth.admin.createUser({
      email: payload.email.trim(),
      password: payload.password,
      email_confirm: true,
      user_metadata: {
        display_name: payload.displayName.trim(),
      },
    })

  if (createUserError || !createdUser.user) {
    return json(
      { error: createUserError?.message ?? 'Failed to create auth user.' },
      400,
    )
  }

  const nextUser = createdUser.user

  const { error: profileError } = await adminClient
    .from('profiles')
    .upsert({
      id: nextUser.id,
      display_name: payload.displayName.trim(),
      phone: payload.phone?.trim() || null,
    })

  if (profileError) {
    await adminClient.auth.admin.deleteUser(nextUser.id)
    return json({ error: profileError.message }, 400)
  }

  const { error: membershipInsertError } = await adminClient.from('memberships').insert({
    user_id: nextUser.id,
    school_id: payload.schoolId,
    class_id: payload.classId ?? null,
    role: payload.role,
    status: 'active',
  })

  if (membershipInsertError) {
    await adminClient.auth.admin.deleteUser(nextUser.id)
    return json({ error: membershipInsertError.message }, 400)
  }

  return json({
    userId: nextUser.id,
    email: nextUser.email,
    role: payload.role,
    schoolId: payload.schoolId,
    classId: payload.classId ?? null,
  })
})
