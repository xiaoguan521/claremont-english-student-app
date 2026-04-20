create extension if not exists pg_net;
create extension if not exists pg_cron;

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

drop trigger if exists trg_submissions_enqueue_ai_review on public.submissions;
create trigger trg_submissions_enqueue_ai_review
  after insert or update of status on public.submissions
  for each row
  execute function public.enqueue_evaluation_job_from_submission();

create or replace function public.schedule_ai_review_queue_worker(
  project_url text,
  queue_secret text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_job record;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron')
     or not exists (select 1 from pg_extension where extname = 'pg_net') then
    return;
  end if;

  if coalesce(project_url, '') = '' or coalesce(queue_secret, '') = '' then
    return;
  end if;

  for existing_job in
    select jobid from cron.job where jobname = 'ai-review-queue-worker'
  loop
    perform cron.unschedule(existing_job.jobid);
  end loop;

  perform cron.schedule(
    'ai-review-queue-worker',
    '* * * * *',
    format(
      $sql$
      select
        net.http_post(
          url := '%s/functions/v1/ai-review-submission',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-queue-secret', %L
          ),
          body := '{"action":"process_queue","batchSize":3}'::jsonb
        ) as request_id;
      $sql$,
      rtrim(project_url, '/'),
      queue_secret
    )
  );
end;
$$;
