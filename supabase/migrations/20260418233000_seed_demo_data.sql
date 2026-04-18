do $$
declare
  admin_user_id uuid;
  teacher_user_id uuid;
  student_user_id uuid;
  v_school_id uuid;
  v_class_id uuid;
  v_material_id uuid;
  v_assignment_id uuid;
begin
  select id into admin_user_id
  from auth.users
  where email = 'admin@claremont.local'
  limit 1;

  select id into teacher_user_id
  from auth.users
  where email = 'teacher@claremont.local'
  limit 1;

  select id into student_user_id
  from auth.users
  where email = 'student@claremont.local'
  limit 1;

  if admin_user_id is null or teacher_user_id is null or student_user_id is null then
    raise exception
      'Please create auth users first: admin@claremont.local, teacher@claremont.local, student@claremont.local';
  end if;

  insert into public.schools (id, name, code, contact_name, contact_phone, created_by)
  values (
    gen_random_uuid(),
    '克莱蒙英语示范校区',
    'claremont-demo',
    '校区管理员',
    '13800000000',
    admin_user_id
  )
  on conflict (code) do update
  set
    name = excluded.name,
    contact_name = excluded.contact_name,
    contact_phone = excluded.contact_phone,
    created_by = excluded.created_by;

  select id into v_school_id
  from public.schools
  where code = 'claremont-demo'
  limit 1;

  select id into v_class_id
  from public.classes
  where school_id = v_school_id
    and name = '精品英语 H 班'
  order by created_at asc
  limit 1;

  if v_class_id is null then
    insert into public.classes (
      id,
      school_id,
      name,
      grade_label,
      academic_year,
      created_by
    )
    values (
      gen_random_uuid(),
      v_school_id,
      '精品英语 H 班',
      '三年级',
      '2025-2026',
      admin_user_id
    )
    returning id into v_class_id;
  end if;

  update public.profiles
  set display_name = '校区管理员'
  where id = admin_user_id;

  update public.profiles
  set display_name = '王老师'
  where id = teacher_user_id;

  update public.profiles
  set display_name = '李同学'
  where id = student_user_id;

  insert into public.memberships (user_id, school_id, role, status)
  select admin_user_id, v_school_id, 'school_admin', 'active'
  where not exists (
    select 1
    from public.memberships
    where user_id = admin_user_id
      and school_id = v_school_id
      and class_id is null
      and role = 'school_admin'
  );

  insert into public.memberships (user_id, school_id, class_id, role, status)
  select teacher_user_id, v_school_id, v_class_id, 'teacher', 'active'
  where not exists (
    select 1
    from public.memberships
    where user_id = teacher_user_id
      and school_id = v_school_id
      and class_id = v_class_id
      and role = 'teacher'
  );

  insert into public.memberships (user_id, school_id, class_id, role, status)
  select student_user_id, v_school_id, v_class_id, 'student', 'active'
  where not exists (
    select 1
    from public.memberships
    where user_id = student_user_id
      and school_id = v_school_id
      and class_id = v_class_id
      and role = 'student'
  );

  select id into v_material_id
  from public.materials
  where school_id = v_school_id
    and title = 'Module 7 阅读教材'
  order by created_at asc
  limit 1;

  if v_material_id is null then
    insert into public.materials (
      id,
      school_id,
      title,
      description,
      pdf_path,
      status,
      uploaded_by
    )
    values (
      gen_random_uuid(),
      v_school_id,
      'Module 7 阅读教材',
      '示例教材，占位用路径。',
      v_school_id::text || '/module-7/source.pdf',
      'published',
      teacher_user_id
    )
    returning id into v_material_id;
  end if;

  select id into v_assignment_id
  from public.assignments
  where class_id = v_class_id
    and title = '7 天打卡活动'
  order by created_at asc
  limit 1;

  if v_assignment_id is null then
    insert into public.assignments (
      id,
      school_id,
      class_id,
      material_id,
      title,
      description,
      due_at,
      status,
      created_by
    )
    values (
      gen_random_uuid(),
      v_school_id,
      v_class_id,
      v_material_id,
      '7 天打卡活动',
      '完成 Module 7 的示范朗读与录音提交。',
      timezone('utc', now()) + interval '7 day',
      'published',
      teacher_user_id
    )
    returning id into v_assignment_id;
  end if;

  if not exists (
    select 1
    from public.assignment_items
    where assignment_id = v_assignment_id
      and sort_order = 1
  ) then
    insert into public.assignment_items (
      assignment_id,
      sort_order,
      item_type,
      title,
      prompt_text,
      tts_text,
      expected_text,
      start_page,
      end_page
    )
    values
      (
        v_assignment_id,
        1,
        'sentence',
        'Module 7-1',
        'Read the sentence about things you can and cannot do.',
        'I can swim, but I cannot dive.',
        'I can swim, but I cannot dive.',
        1,
        1
      ),
      (
        v_assignment_id,
        2,
        'sentence',
        'Module 7-2',
        'Read the second sentence clearly and confidently.',
        'He can sing well, but he cannot skate.',
        'He can sing well, but he cannot skate.',
        2,
        2
      );
  end if;
end $$;
