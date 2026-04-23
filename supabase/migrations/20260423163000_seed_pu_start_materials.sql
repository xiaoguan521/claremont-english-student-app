do $$
declare
  teacher_user_id uuid;
  v_school_id uuid;
  v_class_id uuid;

  v_material_hello_id uuid;
  v_page_hello_id uuid;
  v_region_hello_id uuid;
  v_audio_hello_id uuid;
  v_video_hello_id uuid;
  v_assignment_hello_id uuid;
  v_assignment_hello_item_id uuid;

  v_material_numbers_id uuid;
  v_page_numbers_id uuid;
  v_region_numbers_id uuid;
  v_audio_numbers_id uuid;
  v_video_numbers_id uuid;
  v_assignment_numbers_id uuid;
  v_assignment_numbers_item_id uuid;
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

  select id into v_material_hello_id
  from public.materials
  where school_id = v_school_id
    and title = 'PU Start · Hello'
  order by created_at asc
  limit 1;

  if v_material_hello_id is null then
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
      'PU Start · Hello',
      'Power Up Starter Unit 的问候试点页，支持教材页内点句子、听示范、看动画和录音提交。',
      'asset:assets/textbooks/power-up/page-4.pdf',
      'asset:assets/textbooks/power-up/page-4.png',
      1,
      'published',
      teacher_user_id
    )
    returning id into v_material_hello_id;
  else
    update public.materials
    set
      description = 'Power Up Starter Unit 的问候试点页，支持教材页内点句子、听示范、看动画和录音提交。',
      pdf_path = 'asset:assets/textbooks/power-up/page-4.pdf',
      cover_image_path = 'asset:assets/textbooks/power-up/page-4.png',
      page_count = 1,
      status = 'published',
      updated_at = timezone('utc', now())
    where id = v_material_hello_id;
  end if;

  select id into v_page_hello_id
  from public.material_pages
  where material_id = v_material_hello_id
    and page_number = 4
  limit 1;

  if v_page_hello_id is null then
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
      v_material_hello_id,
      4,
      'asset:assets/textbooks/power-up/page-4.png',
      2355,
      2967,
      'active',
      teacher_user_id
    )
    returning id into v_page_hello_id;
  else
    update public.material_pages
    set
      image_path = 'asset:assets/textbooks/power-up/page-4.png',
      page_width = 2355,
      page_height = 2967,
      status = 'active',
      updated_at = timezone('utc', now())
    where id = v_page_hello_id;
  end if;

  select id into v_region_hello_id
  from public.material_page_regions
  where material_page_id = v_page_hello_id
    and display_text = 'Hello.'
  limit 1;

  if v_region_hello_id is null then
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
      v_page_hello_id,
      'dialogue',
      1,
      0.28,
      0.06,
      0.30,
      0.10,
      'Hello.',
      '先听示范，再大声说 Hello。',
      'Hello.',
      'Hello.',
      'active',
      teacher_user_id
    )
    returning id into v_region_hello_id;
  else
    update public.material_page_regions
    set
      region_type = 'dialogue',
      sort_order = 1,
      x = 0.28,
      y = 0.06,
      width = 0.30,
      height = 0.10,
      prompt_text = '先听示范，再大声说 Hello。',
      expected_text = 'Hello.',
      tts_text = 'Hello.',
      status = 'active',
      updated_at = timezone('utc', now())
    where id = v_region_hello_id;
  end if;

  select id into v_audio_hello_id
  from public.material_region_assets
  where region_id = v_region_hello_id
    and asset_role = 'reference_audio'
  order by created_at asc
  limit 1;

  if v_audio_hello_id is null then
    insert into public.material_region_assets (
      id,
      region_id,
      asset_type,
      asset_role,
      storage_bucket,
      storage_path,
      mime_type,
      duration_ms,
      provider,
      sort_order,
      status,
      created_by
    )
    values (
      gen_random_uuid(),
      v_region_hello_id,
      'audio',
      'reference_audio',
      'asset',
      'assets/media/power-up/page-4-ex1.mp3',
      'audio/mpeg',
      58220,
      'power-up-local',
      1,
      'active',
      teacher_user_id
    )
    returning id into v_audio_hello_id;
  else
    update public.material_region_assets
    set
      asset_type = 'audio',
      storage_bucket = 'asset',
      storage_path = 'assets/media/power-up/page-4-ex1.mp3',
      mime_type = 'audio/mpeg',
      duration_ms = 58220,
      provider = 'power-up-local',
      sort_order = 1,
      status = 'active',
      updated_at = timezone('utc', now())
    where id = v_audio_hello_id;
  end if;

  select id into v_video_hello_id
  from public.material_region_assets
  where region_id = v_region_hello_id
    and asset_role = 'teaching_video'
  order by created_at asc
  limit 1;

  if v_video_hello_id is null then
    insert into public.material_region_assets (
      id,
      region_id,
      asset_type,
      asset_role,
      storage_bucket,
      storage_path,
      mime_type,
      provider,
      sort_order,
      status,
      created_by
    )
    values (
      gen_random_uuid(),
      v_region_hello_id,
      'video',
      'teaching_video',
      'asset',
      'assets/media/power-up/page-4-demo.mp4',
      'video/mp4',
      'power-up-local',
      2,
      'active',
      teacher_user_id
    )
    returning id into v_video_hello_id;
  else
    update public.material_region_assets
    set
      asset_type = 'video',
      storage_bucket = 'asset',
      storage_path = 'assets/media/power-up/page-4-demo.mp4',
      mime_type = 'video/mp4',
      provider = 'power-up-local',
      sort_order = 2,
      status = 'active',
      updated_at = timezone('utc', now())
    where id = v_video_hello_id;
  end if;

  select id into v_assignment_hello_id
  from public.assignments
  where class_id = v_class_id
    and title = 'PU Start 问候练习'
  order by created_at asc
  limit 1;

  if v_assignment_hello_id is null then
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
      v_material_hello_id,
      'PU Start 问候练习',
      '在课本页里点击 Hello，先听示范，再录音提交。',
      timezone('utc', now()) + interval '4 day',
      'published',
      teacher_user_id
    )
    returning id into v_assignment_hello_id;
  else
    update public.assignments
    set
      material_id = v_material_hello_id,
      description = '在课本页里点击 Hello，先听示范，再录音提交。',
      due_at = timezone('utc', now()) + interval '4 day',
      status = 'published',
      updated_at = timezone('utc', now())
    where id = v_assignment_hello_id;
  end if;

  select id into v_assignment_hello_item_id
  from public.assignment_items
  where assignment_id = v_assignment_hello_id
    and sort_order = 1
  limit 1;

  if v_assignment_hello_item_id is null then
    insert into public.assignment_items (
      id,
      assignment_id,
      sort_order,
      item_type,
      title,
      prompt_text,
      tts_text,
      expected_text,
      start_page,
      end_page,
      region_id
    )
    values (
      gen_random_uuid(),
      v_assignment_hello_id,
      1,
      'sentence',
      'Hello 练习',
      '先听示范，再大声说 Hello。',
      'Hello.',
      'Hello.',
      4,
      4,
      v_region_hello_id
    )
    returning id into v_assignment_hello_item_id;
  else
    update public.assignment_items
    set
      item_type = 'sentence',
      title = 'Hello 练习',
      prompt_text = '先听示范，再大声说 Hello。',
      tts_text = 'Hello.',
      expected_text = 'Hello.',
      start_page = 4,
      end_page = 4,
      region_id = v_region_hello_id
    where id = v_assignment_hello_item_id;
  end if;

  select id into v_material_numbers_id
  from public.materials
  where school_id = v_school_id
    and title = 'PU Start · Numbers 1-6'
  order by created_at asc
  limit 1;

  if v_material_numbers_id is null then
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
      'PU Start · Numbers 1-6',
      'Power Up Starter Unit 的数字练习页，支持边看教材边数数字并提交录音。',
      'asset:assets/textbooks/power-up/page-6.pdf',
      'asset:assets/textbooks/power-up/page-6.png',
      1,
      'published',
      teacher_user_id
    )
    returning id into v_material_numbers_id;
  else
    update public.materials
    set
      description = 'Power Up Starter Unit 的数字练习页，支持边看教材边数数字并提交录音。',
      pdf_path = 'asset:assets/textbooks/power-up/page-6.pdf',
      cover_image_path = 'asset:assets/textbooks/power-up/page-6.png',
      page_count = 1,
      status = 'published',
      updated_at = timezone('utc', now())
    where id = v_material_numbers_id;
  end if;

  select id into v_page_numbers_id
  from public.material_pages
  where material_id = v_material_numbers_id
    and page_number = 6
  limit 1;

  if v_page_numbers_id is null then
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
      v_material_numbers_id,
      6,
      'asset:assets/textbooks/power-up/page-6.png',
      2355,
      2967,
      'active',
      teacher_user_id
    )
    returning id into v_page_numbers_id;
  else
    update public.material_pages
    set
      image_path = 'asset:assets/textbooks/power-up/page-6.png',
      page_width = 2355,
      page_height = 2967,
      status = 'active',
      updated_at = timezone('utc', now())
    where id = v_page_numbers_id;
  end if;

  select id into v_region_numbers_id
  from public.material_page_regions
  where material_page_id = v_page_numbers_id
    and display_text = 'One, two, three, four, five, six.'
  limit 1;

  if v_region_numbers_id is null then
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
      v_page_numbers_id,
      'sentence',
      1,
      0.10,
      0.14,
      0.82,
      0.46,
      'One, two, three, four, five, six.',
      '先看着气球，再跟着示范数一数 1 到 6。',
      'One, two, three, four, five, six.',
      'One, two, three, four, five, six.',
      'active',
      teacher_user_id
    )
    returning id into v_region_numbers_id;
  else
    update public.material_page_regions
    set
      region_type = 'sentence',
      sort_order = 1,
      x = 0.10,
      y = 0.14,
      width = 0.82,
      height = 0.46,
      prompt_text = '先看着气球，再跟着示范数一数 1 到 6。',
      expected_text = 'One, two, three, four, five, six.',
      tts_text = 'One, two, three, four, five, six.',
      status = 'active',
      updated_at = timezone('utc', now())
    where id = v_region_numbers_id;
  end if;

  select id into v_audio_numbers_id
  from public.material_region_assets
  where region_id = v_region_numbers_id
    and asset_role = 'reference_audio'
  order by created_at asc
  limit 1;

  if v_audio_numbers_id is null then
    insert into public.material_region_assets (
      id,
      region_id,
      asset_type,
      asset_role,
      storage_bucket,
      storage_path,
      mime_type,
      duration_ms,
      provider,
      sort_order,
      status,
      created_by
    )
    values (
      gen_random_uuid(),
      v_region_numbers_id,
      'audio',
      'reference_audio',
      'asset',
      'assets/media/power-up/page-6-ex1.mp3',
      'audio/mpeg',
      27890,
      'power-up-local',
      1,
      'active',
      teacher_user_id
    )
    returning id into v_audio_numbers_id;
  else
    update public.material_region_assets
    set
      asset_type = 'audio',
      storage_bucket = 'asset',
      storage_path = 'assets/media/power-up/page-6-ex1.mp3',
      mime_type = 'audio/mpeg',
      duration_ms = 27890,
      provider = 'power-up-local',
      sort_order = 1,
      status = 'active',
      updated_at = timezone('utc', now())
    where id = v_audio_numbers_id;
  end if;

  select id into v_video_numbers_id
  from public.material_region_assets
  where region_id = v_region_numbers_id
    and asset_role = 'teaching_video'
  order by created_at asc
  limit 1;

  if v_video_numbers_id is null then
    insert into public.material_region_assets (
      id,
      region_id,
      asset_type,
      asset_role,
      storage_bucket,
      storage_path,
      mime_type,
      provider,
      sort_order,
      status,
      created_by
    )
    values (
      gen_random_uuid(),
      v_region_numbers_id,
      'video',
      'teaching_video',
      'asset',
      'assets/media/power-up/page-6-demo.mp4',
      'video/mp4',
      'power-up-local',
      2,
      'active',
      teacher_user_id
    )
    returning id into v_video_numbers_id;
  else
    update public.material_region_assets
    set
      asset_type = 'video',
      storage_bucket = 'asset',
      storage_path = 'assets/media/power-up/page-6-demo.mp4',
      mime_type = 'video/mp4',
      provider = 'power-up-local',
      sort_order = 2,
      status = 'active',
      updated_at = timezone('utc', now())
    where id = v_video_numbers_id;
  end if;

  select id into v_assignment_numbers_id
  from public.assignments
  where class_id = v_class_id
    and title = 'PU Start 数字 1-6'
  order by created_at asc
  limit 1;

  if v_assignment_numbers_id is null then
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
      v_material_numbers_id,
      'PU Start 数字 1-6',
      '在教材页里点数字区域，边听边数，再录音提交。',
      timezone('utc', now()) + interval '5 day',
      'published',
      teacher_user_id
    )
    returning id into v_assignment_numbers_id;
  else
    update public.assignments
    set
      material_id = v_material_numbers_id,
      description = '在教材页里点数字区域，边听边数，再录音提交。',
      due_at = timezone('utc', now()) + interval '5 day',
      status = 'published',
      updated_at = timezone('utc', now())
    where id = v_assignment_numbers_id;
  end if;

  select id into v_assignment_numbers_item_id
  from public.assignment_items
  where assignment_id = v_assignment_numbers_id
    and sort_order = 1
  limit 1;

  if v_assignment_numbers_item_id is null then
    insert into public.assignment_items (
      id,
      assignment_id,
      sort_order,
      item_type,
      title,
      prompt_text,
      tts_text,
      expected_text,
      start_page,
      end_page,
      region_id
    )
    values (
      gen_random_uuid(),
      v_assignment_numbers_id,
      1,
      'sentence',
      '数字 1-6',
      '先看着气球，再跟着示范数一数 1 到 6。',
      'One, two, three, four, five, six.',
      'One, two, three, four, five, six.',
      6,
      6,
      v_region_numbers_id
    )
    returning id into v_assignment_numbers_item_id;
  else
    update public.assignment_items
    set
      item_type = 'sentence',
      title = '数字 1-6',
      prompt_text = '先看着气球，再跟着示范数一数 1 到 6。',
      tts_text = 'One, two, three, four, five, six.',
      expected_text = 'One, two, three, four, five, six.',
      start_page = 6,
      end_page = 6,
      region_id = v_region_numbers_id
    where id = v_assignment_numbers_item_id;
  end if;
end
$$;
