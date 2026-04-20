do $$
declare
  admin_user_id uuid;
  teacher_user_id uuid;
  student_user_id uuid;
  v_school_id uuid;
  v_class_id uuid;
  v_material_warmup_id uuid;
  v_material_phonics_id uuid;
  v_material_story_id uuid;
  v_assignment_warmup_id uuid;
  v_assignment_phonics_id uuid;
  v_assignment_story_id uuid;
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

  select id into v_school_id
  from public.schools
  where code = 'claremont-demo'
  limit 1;

  if v_school_id is null then
    raise exception 'School claremont-demo does not exist. Run the initial seed first.';
  end if;

  select id into v_class_id
  from public.classes
  where school_id = v_school_id
    and name = '精品英语 H 班'
  order by created_at asc
  limit 1;

  if v_class_id is null then
    raise exception 'Class 精品英语 H 班 does not exist. Run the initial seed first.';
  end if;

  update public.profiles
  set display_name = '李同学'
  where id = student_user_id;

  select id into v_material_warmup_id
  from public.materials
  where school_id = v_school_id
    and title = '早读热身 1'
  order by created_at asc
  limit 1;

  if v_material_warmup_id is null then
    insert into public.materials (
      id,
      school_id,
      title,
      description,
      pdf_path,
      page_count,
      status,
      uploaded_by
    )
    values (
      gen_random_uuid(),
      v_school_id,
      '早读热身 1',
      '适合早晨打开就能读的一页短句练习。',
      v_school_id::text || '/warmup/warmup-reading-1.pdf',
      2,
      'published',
      teacher_user_id
    )
    returning id into v_material_warmup_id;
  end if;

  select id into v_material_phonics_id
  from public.materials
  where school_id = v_school_id
    and title = '自然拼读练习 A'
  order by created_at asc
  limit 1;

  if v_material_phonics_id is null then
    insert into public.materials (
      id,
      school_id,
      title,
      description,
      pdf_path,
      page_count,
      status,
      uploaded_by
    )
    values (
      gen_random_uuid(),
      v_school_id,
      '自然拼读练习 A',
      '短元音 a 的自然拼读练习，适合学生端验证听示范与录音。',
      v_school_id::text || '/phonics/phonics-short-a.pdf',
      2,
      'published',
      teacher_user_id
    )
    returning id into v_material_phonics_id;
  end if;

  select id into v_material_story_id
  from public.materials
  where school_id = v_school_id
    and title = '小故事朗读 1'
  order by created_at asc
  limit 1;

  if v_material_story_id is null then
    insert into public.materials (
      id,
      school_id,
      title,
      description,
      pdf_path,
      page_count,
      status,
      uploaded_by
    )
    values (
      gen_random_uuid(),
      v_school_id,
      '小故事朗读 1',
      '一页迷你故事，适合验证 AI 初评与老师复核。',
      v_school_id::text || '/stories/story-reading-1.pdf',
      3,
      'published',
      teacher_user_id
    )
    returning id into v_material_story_id;
  end if;

  select id into v_assignment_warmup_id
  from public.assignments
  where class_id = v_class_id
    and title = '早读热身 1'
  order by created_at asc
  limit 1;

  if v_assignment_warmup_id is null then
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
      v_material_warmup_id,
      '早读热身 1',
      '完成 2 句早读热身朗读并提交录音。',
      timezone('utc', now()) + interval '3 day',
      'published',
      teacher_user_id
    )
    returning id into v_assignment_warmup_id;
  end if;

  if not exists (
    select 1
    from public.assignment_items
    where assignment_id = v_assignment_warmup_id
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
        v_assignment_warmup_id,
        1,
        'sentence',
        '早读句子 1',
        'Read the sentence about introducing yourself.',
        'Hello, my name is Lily.',
        'Hello, my name is Lily.',
        1,
        1
      ),
      (
        v_assignment_warmup_id,
        2,
        'sentence',
        '早读句子 2',
        'Read the sentence about reading after school.',
        'I like reading after school.',
        'I like reading after school.',
        2,
        2
      );
  end if;

  select id into v_assignment_phonics_id
  from public.assignments
  where class_id = v_class_id
    and title = '自然拼读练习 A'
  order by created_at asc
  limit 1;

  if v_assignment_phonics_id is null then
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
      v_material_phonics_id,
      '自然拼读练习 A',
      '跟读短元音 a 的发音并提交录音。',
      timezone('utc', now()) + interval '5 day',
      'published',
      teacher_user_id
    )
    returning id into v_assignment_phonics_id;
  end if;

  if not exists (
    select 1
    from public.assignment_items
    where assignment_id = v_assignment_phonics_id
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
        v_assignment_phonics_id,
        1,
        'sentence',
        '自然拼读 1',
        'Read the short a word line slowly and clearly.',
        'cat, map, bag',
        'cat, map, bag',
        1,
        1
      ),
      (
        v_assignment_phonics_id,
        2,
        'sentence',
        '自然拼读 2',
        'Read the second line with the same vowel sound.',
        'jam, hat, cap',
        'jam, hat, cap',
        2,
        2
      );
  end if;

  select id into v_assignment_story_id
  from public.assignments
  where class_id = v_class_id
    and title = '小故事朗读 1'
  order by created_at asc
  limit 1;

  if v_assignment_story_id is null then
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
      v_material_story_id,
      '小故事朗读 1',
      '朗读一段 3 句小故事，验证 AI 初评和老师复核流程。',
      timezone('utc', now()) + interval '7 day',
      'published',
      teacher_user_id
    )
    returning id into v_assignment_story_id;
  end if;

  if not exists (
    select 1
    from public.assignment_items
    where assignment_id = v_assignment_story_id
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
        v_assignment_story_id,
        1,
        'sentence',
        '故事句子 1',
        'Read the first sentence of the mini story.',
        'Tom has a red bag.',
        'Tom has a red bag.',
        1,
        1
      ),
      (
        v_assignment_story_id,
        2,
        'sentence',
        '故事句子 2',
        'Read the second sentence naturally.',
        'He reads on the bus.',
        'He reads on the bus.',
        2,
        2
      ),
      (
        v_assignment_story_id,
        3,
        'sentence',
        '故事句子 3',
        'Read the last sentence with a confident voice.',
        'He likes the funny story.',
        'He likes the funny story.',
        3,
        3
      );
  end if;
end $$;
