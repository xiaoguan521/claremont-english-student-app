drop policy if exists "submission_audio_objects_select_owner_or_staff" on storage.objects;
create policy "submission_audio_objects_select_owner_or_staff"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'submission-audio'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.can_read_submission((storage.foldername(name))[1]::uuid)
  );

drop policy if exists "submission_audio_objects_insert_owner_or_staff" on storage.objects;
create policy "submission_audio_objects_insert_owner_or_staff"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'submission-audio'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.can_read_submission((storage.foldername(name))[1]::uuid)
  );

drop policy if exists "submission_audio_objects_update_owner_or_staff" on storage.objects;
create policy "submission_audio_objects_update_owner_or_staff"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'submission-audio'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.can_read_submission((storage.foldername(name))[1]::uuid)
  )
  with check (
    bucket_id = 'submission-audio'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.can_read_submission((storage.foldername(name))[1]::uuid)
  );

drop policy if exists "submission_audio_objects_delete_owner_or_staff" on storage.objects;
create policy "submission_audio_objects_delete_owner_or_staff"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'submission-audio'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.can_read_submission((storage.foldername(name))[1]::uuid)
  );
