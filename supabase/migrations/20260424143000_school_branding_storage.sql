insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'school-branding',
    'school-branding',
    true,
    2097152,
    array[
      'image/png',
      'image/jpeg',
      'image/webp'
    ]
  )
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "school_branding_objects_insert_admin" on storage.objects;
create policy "school_branding_objects_insert_admin"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'school-branding'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and lower(coalesce(storage.extension(name), '')) = any (
      array['png', 'jpg', 'jpeg', 'webp']
    )
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin']::public.app_role[]
    )
  );

drop policy if exists "school_branding_objects_update_admin" on storage.objects;
create policy "school_branding_objects_update_admin"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'school-branding'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin']::public.app_role[]
    )
  )
  with check (
    bucket_id = 'school-branding'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin']::public.app_role[]
    )
  );

drop policy if exists "school_branding_objects_delete_admin" on storage.objects;
create policy "school_branding_objects_delete_admin"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'school-branding'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin']::public.app_role[]
    )
  );
