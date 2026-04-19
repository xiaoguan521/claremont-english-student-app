drop policy if exists "evaluation_results_insert_owner_or_staff" on public.evaluation_results;
create policy "evaluation_results_insert_owner_or_staff"
  on public.evaluation_results
  for insert
  to authenticated
  with check (public.can_read_submission(submission_id));

drop policy if exists "evaluation_results_update_owner_or_staff" on public.evaluation_results;
create policy "evaluation_results_update_owner_or_staff"
  on public.evaluation_results
  for update
  to authenticated
  using (public.can_read_submission(submission_id))
  with check (public.can_read_submission(submission_id));
