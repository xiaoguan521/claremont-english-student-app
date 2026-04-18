drop policy if exists "materials_objects_select_same_school" on storage.objects;
create policy "materials_objects_select_same_school"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'materials'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher', 'student', 'parent']::public.app_role[]
    )
  );

drop policy if exists "materials_objects_insert_staff" on storage.objects;
create policy "materials_objects_insert_staff"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'materials'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and lower(storage.extension(name)) = 'pdf'
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );

drop policy if exists "materials_objects_update_staff" on storage.objects;
create policy "materials_objects_update_staff"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'materials'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  )
  with check (
    bucket_id = 'materials'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );

drop policy if exists "materials_objects_delete_staff" on storage.objects;
create policy "materials_objects_delete_staff"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'materials'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );
