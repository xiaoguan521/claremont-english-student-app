insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'reference-audio',
    'reference-audio',
    false,
    15728640,
    array[
      'audio/mpeg',
      'audio/mp4',
      'audio/wav',
      'audio/x-wav',
      'audio/aac',
      'audio/webm',
      'audio/ogg'
    ]
  )
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "reference_audio_objects_select_same_school" on storage.objects;
create policy "reference_audio_objects_select_same_school"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'reference-audio'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher', 'student', 'parent']::public.app_role[]
    )
  );

drop policy if exists "reference_audio_objects_insert_staff" on storage.objects;
create policy "reference_audio_objects_insert_staff"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'reference-audio'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and lower(coalesce(storage.extension(name), '')) = any (
      array['mp3', 'm4a', 'mp4', 'wav', 'aac', 'webm', 'ogg']
    )
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );

drop policy if exists "reference_audio_objects_update_staff" on storage.objects;
create policy "reference_audio_objects_update_staff"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'reference-audio'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  )
  with check (
    bucket_id = 'reference-audio'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );

drop policy if exists "reference_audio_objects_delete_staff" on storage.objects;
create policy "reference_audio_objects_delete_staff"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'reference-audio'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );
