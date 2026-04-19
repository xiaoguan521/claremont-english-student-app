do $$
declare
  student_user_id uuid;
  v_assignment_id uuid;
  v_submission_id uuid;
begin
  select id into student_user_id
  from auth.users
  where email = 'student@claremont.local'
  limit 1;

  select a.id
  into v_assignment_id
  from public.assignments a
  join public.schools s on s.id = a.school_id
  where s.code = 'claremont-demo'
    and a.title = '7 天打卡活动'
  order by a.created_at asc
  limit 1;

  if student_user_id is null or v_assignment_id is null then
    raise exception 'Missing demo student user or assignment for feedback seed.';
  end if;

  insert into public.submissions (
    assignment_id,
    student_id,
    status,
    submitted_at,
    latest_score,
    latest_feedback
  )
  values (
    v_assignment_id,
    student_user_id,
    'completed',
    timezone('utc', now()) - interval '1 day',
    95,
    '你这次的朗读节奏很稳，句子衔接也更自然了。'
  )
  on conflict (assignment_id, student_id) do update
  set
    status = excluded.status,
    submitted_at = excluded.submitted_at,
    latest_score = excluded.latest_score,
    latest_feedback = excluded.latest_feedback,
    updated_at = timezone('utc', now())
  returning id into v_submission_id;

  if v_submission_id is null then
    select id into v_submission_id
    from public.submissions
    where assignment_id = v_assignment_id
      and student_id = student_user_id
    limit 1;
  end if;

  insert into public.submission_assets (
    submission_id,
    asset_type,
    storage_bucket,
    storage_path,
    mime_type,
    size_bytes
  )
  select
    v_submission_id,
    'audio',
    'submission-audio',
    v_submission_id::text || '/demo-reading.m4a',
    'audio/mp4',
    1048576
  where not exists (
    select 1
    from public.submission_assets
    where submission_id = v_submission_id
      and asset_type = 'audio'
  );

  insert into public.evaluation_results (
    submission_id,
    provider,
    overall_score,
    pronunciation_score,
    fluency_score,
    completeness_score,
    strengths,
    improvement_points,
    encouragement
  )
  values (
    v_submission_id,
    'demo-teacher-review',
    95,
    94,
    96,
    95,
    '["开头发音清晰", "整体节奏稳定"]'::jsonb,
    '["句尾收音再干净一点"]'::jsonb,
    '继续保持这个状态，下一次把句尾再收紧一点会更棒。'
  )
  on conflict (submission_id) do update
  set
    provider = excluded.provider,
    overall_score = excluded.overall_score,
    pronunciation_score = excluded.pronunciation_score,
    fluency_score = excluded.fluency_score,
    completeness_score = excluded.completeness_score,
    strengths = excluded.strengths,
    improvement_points = excluded.improvement_points,
    encouragement = excluded.encouragement,
    updated_at = timezone('utc', now());
end $$;
