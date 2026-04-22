do $$
declare
  teacher_user_id uuid;
  v_school_id uuid;
  v_class_id uuid;
  v_material_id uuid;
  v_page_id uuid;
  v_region_teacher_id uuid;
  v_region_student_id uuid;
  v_assignment_id uuid;
begin
  select id into teacher_user_id
  from auth.users
  where email = 'teacher@claremont.local'
  limit 1;

  if teacher_user_id is null then
    raise exception 'Teacher user teacher@claremont.local does not exist.';
  end if;

  select id into v_school_id
  from public.schools
  where code = 'claremont-demo'
  limit 1;

  if v_school_id is null then
    raise exception 'School claremont-demo does not exist. Run the base seed first.';
  end if;

  select id into v_class_id
  from public.classes
  where school_id = v_school_id
    and name = '精品英语 H 班'
  order by created_at asc
  limit 1;

  if v_class_id is null then
    raise exception 'Class 精品英语 H 班 does not exist. Run the base seed first.';
  end if;

  select id into v_material_id
  from public.materials
  where school_id = v_school_id
    and title = '一年级 Starter 对话页'
  order by created_at asc
  limit 1;

  if v_material_id is null then
    insert into public.materials (
      id,
      school_id,
      title,
      description,
      pdf_path,
      cover_image_path,
      page_count,
      status,
      uploaded_by
    )
    values (
      gen_random_uuid(),
      v_school_id,
      '一年级 Starter 对话页',
      '一年级上册 Starter 对话页试点，使用教材页内点句子完成示范、录音与提交。',
      v_school_id::text || '/textbooks/grade1-starter.pdf',
      'asset:assets/textbooks/grade1-starter-page-2.png',
      1,
      'published',
      teacher_user_id
    )
    returning id into v_material_id;
  else
    update public.materials
    set
      description = '一年级上册 Starter 对话页试点，使用教材页内点句子完成示范、录音与提交。',
      cover_image_path = 'asset:assets/textbooks/grade1-starter-page-2.png',
      page_count = 1,
      status = 'published',
      updated_at = timezone('utc', now())
    where id = v_material_id;
  end if;

  select id into v_page_id
  from public.material_pages
  where material_id = v_material_id
    and page_number = 2
  limit 1;

  if v_page_id is null then
    insert into public.material_pages (
      id,
      material_id,
      page_number,
      image_path,
      page_width,
      page_height,
      status,
      created_by
    )
    values (
      gen_random_uuid(),
      v_material_id,
      2,
      'asset:assets/textbooks/grade1-starter-page-2.png',
      1123,
      1571,
      'active',
      teacher_user_id
    )
    returning id into v_page_id;
  else
    update public.material_pages
    set
      image_path = 'asset:assets/textbooks/grade1-starter-page-2.png',
      page_width = 1123,
      page_height = 1571,
      status = 'active',
      updated_at = timezone('utc', now())
    where id = v_page_id;
  end if;

  select id into v_region_teacher_id
  from public.material_page_regions
  where material_page_id = v_page_id
    and display_text = 'Good morning! I''m Miss Wu. What''s your name?'
  limit 1;

  if v_region_teacher_id is null then
    insert into public.material_page_regions (
      id,
      material_page_id,
      region_type,
      sort_order,
      x,
      y,
      width,
      height,
      display_text,
      prompt_text,
      expected_text,
      tts_text,
      status,
      created_by
    )
    values (
      gen_random_uuid(),
      v_page_id,
      'dialogue',
      1,
      0.06,
      0.40,
      0.42,
      0.12,
      'Good morning! I''m Miss Wu. What''s your name?',
      '先听老师问候，再读出 Miss Wu 的问题。',
      'Good morning! I''m Miss Wu. What''s your name?',
      'Good morning! I''m Miss Wu. What''s your name?',
      'active',
      teacher_user_id
    )
    returning id into v_region_teacher_id;
  else
    update public.material_page_regions
    set
      region_type = 'dialogue',
      sort_order = 1,
      x = 0.06,
      y = 0.40,
      width = 0.42,
      height = 0.12,
      display_text = 'Good morning! I''m Miss Wu. What''s your name?',
      prompt_text = '先听老师问候，再读出 Miss Wu 的问题。',
      expected_text = 'Good morning! I''m Miss Wu. What''s your name?',
      tts_text = 'Good morning! I''m Miss Wu. What''s your name?',
      status = 'active',
      updated_at = timezone('utc', now())
    where id = v_region_teacher_id;
  end if;

  select id into v_region_student_id
  from public.material_page_regions
  where material_page_id = v_page_id
    and display_text = 'Hello! My name is Bill.'
  limit 1;

  if v_region_student_id is null then
    insert into public.material_page_regions (
      id,
      material_page_id,
      region_type,
      sort_order,
      x,
      y,
      width,
      height,
      display_text,
      prompt_text,
      expected_text,
      tts_text,
      status,
      created_by
    )
    values (
      gen_random_uuid(),
      v_page_id,
      'dialogue',
      2,
      0.30,
      0.49,
      0.33,
      0.10,
      'Hello! My name is Bill.',
      '轮到 Bill 自我介绍了，注意语气要大方清楚。',
      'Hello! My name is Bill.',
      'Hello! My name is Bill.',
      'active',
      teacher_user_id
    )
    returning id into v_region_student_id;
  else
    update public.material_page_regions
    set
      region_type = 'dialogue',
      sort_order = 2,
      x = 0.30,
      y = 0.49,
      width = 0.33,
      height = 0.10,
      display_text = 'Hello! My name is Bill.',
      prompt_text = '轮到 Bill 自我介绍了，注意语气要大方清楚。',
      expected_text = 'Hello! My name is Bill.',
      tts_text = 'Hello! My name is Bill.',
      status = 'active',
      updated_at = timezone('utc', now())
    where id = v_region_student_id;
  end if;

  select id into v_assignment_id
  from public.assignments
  where class_id = v_class_id
    and title = '一年级 Starter 对话页'
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
      '一年级 Starter 对话页',
      '点击教材页里的对话框，按顺序完成两句问候练习。',
      timezone('utc', now()) + interval '2 day',
      'published',
      teacher_user_id
    )
    returning id into v_assignment_id;
  else
    update public.assignments
    set
      material_id = v_material_id,
      description = '点击教材页里的对话框，按顺序完成两句问候练习。',
      status = 'published',
      updated_at = timezone('utc', now())
    where id = v_assignment_id;
  end if;

  if not exists (
    select 1
    from public.assignment_items
    where assignment_id = v_assignment_id
      and region_id = v_region_teacher_id
  ) then
    insert into public.assignment_items (
      assignment_id,
      region_id,
      sort_order,
      item_type,
      title,
      prompt_text,
      tts_text,
      expected_text,
      start_page,
      end_page
    )
    values (
      v_assignment_id,
      v_region_teacher_id,
      1,
      'sentence',
      'Starter 句子 1',
      '先听老师问候，再读出 Miss Wu 的问题。',
      'Good morning! I''m Miss Wu. What''s your name?',
      'Good morning! I''m Miss Wu. What''s your name?',
      2,
      2
    );
  end if;

  if not exists (
    select 1
    from public.assignment_items
    where assignment_id = v_assignment_id
      and region_id = v_region_student_id
  ) then
    insert into public.assignment_items (
      assignment_id,
      region_id,
      sort_order,
      item_type,
      title,
      prompt_text,
      tts_text,
      expected_text,
      start_page,
      end_page
    )
    values (
      v_assignment_id,
      v_region_student_id,
      2,
      'sentence',
      'Starter 句子 2',
      '轮到 Bill 自我介绍了，注意语气要大方清楚。',
      'Hello! My name is Bill.',
      'Hello! My name is Bill.',
      2,
      2
    );
  end if;
end $$;
