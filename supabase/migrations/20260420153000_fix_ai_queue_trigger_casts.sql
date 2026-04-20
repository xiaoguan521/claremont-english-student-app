create or replace function public.enqueue_evaluation_job_from_submission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status not in ('queued', 'uploaded') then
    return new;
  end if;

  insert into public.evaluation_jobs (
    submission_id,
    provider,
    status,
    last_error,
    request_payload,
    requested_at,
    started_at,
    completed_at,
    updated_at
  )
  values (
    new.id,
    'queued',
    'pending'::public.evaluation_job_status,
    null,
    jsonb_build_object(
      'queueSource',
      'submission-trigger',
      'submissionStatus',
      new.status
    ),
    timezone('utc', now()),
    null,
    null,
    timezone('utc', now())
  )
  on conflict (submission_id) do update
    set status = case
        when public.evaluation_jobs.status = 'failed'::public.evaluation_job_status then 'retrying'::public.evaluation_job_status
        when public.evaluation_jobs.status = 'completed'::public.evaluation_job_status then 'pending'::public.evaluation_job_status
        else 'pending'::public.evaluation_job_status
      end,
      last_error = null,
      started_at = null,
      completed_at = null,
      updated_at = timezone('utc', now()),
      request_payload =
        coalesce(public.evaluation_jobs.request_payload, '{}'::jsonb)
        || jsonb_build_object(
          'queueSource',
          'submission-trigger',
          'submissionStatus',
          new.status
        );

  return new;
end;
$$;
