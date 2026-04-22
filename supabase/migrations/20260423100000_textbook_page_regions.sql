do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'material_region_type'
  ) then
    create type public.material_region_type as enum (
      'word',
      'sentence',
      'dialogue',
      'paragraph'
    );
  end if;

  if not exists (
    select 1
    from pg_type
    where typname = 'material_region_asset_type'
  ) then
    create type public.material_region_asset_type as enum (
      'audio',
      'video',
      'image'
    );
  end if;

  if not exists (
    select 1
    from pg_type
    where typname = 'material_region_asset_role'
  ) then
    create type public.material_region_asset_role as enum (
      'reference_audio',
      'ai_reference_audio',
      'teaching_video',
      'practice_video',
      'poster_image'
    );
  end if;
end
$$;

create table if not exists public.material_pages (
  id uuid primary key default gen_random_uuid(),
  material_id uuid not null references public.materials(id) on delete cascade,
  page_number integer not null check (page_number > 0),
  image_path text,
  thumbnail_path text,
  page_width numeric(10, 2),
  page_height numeric(10, 2),
  status text not null default 'draft',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (material_id, page_number)
);

create table if not exists public.material_page_regions (
  id uuid primary key default gen_random_uuid(),
  material_page_id uuid not null references public.material_pages(id) on delete cascade,
  region_type public.material_region_type not null default 'sentence',
  display_text text not null,
  prompt_text text,
  expected_text text,
  tts_text text,
  x numeric(8, 5) not null check (x >= 0 and x <= 1),
  y numeric(8, 5) not null check (y >= 0 and y <= 1),
  width numeric(8, 5) not null check (width > 0 and width <= 1),
  height numeric(8, 5) not null check (height > 0 and height <= 1),
  sort_order integer not null default 1,
  status text not null default 'draft',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.material_region_assets (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references public.material_page_regions(id) on delete cascade,
  asset_type public.material_region_asset_type not null,
  asset_role public.material_region_asset_role not null,
  storage_bucket text not null,
  storage_path text not null,
  mime_type text,
  duration_ms integer,
  poster_path text,
  provider text,
  sort_order integer not null default 1,
  status text not null default 'active',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_material_pages_material_id
  on public.material_pages(material_id, page_number);

create index if not exists idx_material_page_regions_page_id
  on public.material_page_regions(material_page_id, sort_order);

create index if not exists idx_material_region_assets_region_id
  on public.material_region_assets(region_id, asset_role, sort_order);

alter table public.assignment_items
  add column if not exists region_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'assignment_items_region_id_fkey'
  ) then
    alter table public.assignment_items
      add constraint assignment_items_region_id_fkey
      foreign key (region_id)
      references public.material_page_regions(id)
      on delete set null;
  end if;
end
$$;

drop trigger if exists trg_material_pages_updated_at on public.material_pages;
create trigger trg_material_pages_updated_at
  before update on public.material_pages
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_material_page_regions_updated_at on public.material_page_regions;
create trigger trg_material_page_regions_updated_at
  before update on public.material_page_regions
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_material_region_assets_updated_at on public.material_region_assets;
create trigger trg_material_region_assets_updated_at
  before update on public.material_region_assets
  for each row execute procedure public.set_updated_at();

alter table public.material_pages enable row level security;
alter table public.material_page_regions enable row level security;
alter table public.material_region_assets enable row level security;

drop policy if exists "material_pages_select_same_school" on public.material_pages;
create policy "material_pages_select_same_school"
  on public.material_pages
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.materials m
      where m.id = material_pages.material_id
        and public.has_school_role(
          m.school_id,
          array['school_admin', 'teacher', 'student', 'parent']::public.app_role[]
        )
    )
  );

drop policy if exists "material_pages_manage_staff" on public.material_pages;
create policy "material_pages_manage_staff"
  on public.material_pages
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.materials m
      where m.id = material_pages.material_id
        and public.has_school_role(
          m.school_id,
          array['school_admin', 'teacher']::public.app_role[]
        )
    )
  )
  with check (
    exists (
      select 1
      from public.materials m
      where m.id = material_pages.material_id
        and public.has_school_role(
          m.school_id,
          array['school_admin', 'teacher']::public.app_role[]
        )
    )
  );

drop policy if exists "material_page_regions_select_same_school" on public.material_page_regions;
create policy "material_page_regions_select_same_school"
  on public.material_page_regions
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.material_pages mp
      join public.materials m
        on m.id = mp.material_id
      where mp.id = material_page_regions.material_page_id
        and public.has_school_role(
          m.school_id,
          array['school_admin', 'teacher', 'student', 'parent']::public.app_role[]
        )
    )
  );

drop policy if exists "material_page_regions_manage_staff" on public.material_page_regions;
create policy "material_page_regions_manage_staff"
  on public.material_page_regions
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.material_pages mp
      join public.materials m
        on m.id = mp.material_id
      where mp.id = material_page_regions.material_page_id
        and public.has_school_role(
          m.school_id,
          array['school_admin', 'teacher']::public.app_role[]
        )
    )
  )
  with check (
    exists (
      select 1
      from public.material_pages mp
      join public.materials m
        on m.id = mp.material_id
      where mp.id = material_page_regions.material_page_id
        and public.has_school_role(
          m.school_id,
          array['school_admin', 'teacher']::public.app_role[]
        )
    )
  );

drop policy if exists "material_region_assets_select_same_school" on public.material_region_assets;
create policy "material_region_assets_select_same_school"
  on public.material_region_assets
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.material_page_regions r
      join public.material_pages mp
        on mp.id = r.material_page_id
      join public.materials m
        on m.id = mp.material_id
      where r.id = material_region_assets.region_id
        and public.has_school_role(
          m.school_id,
          array['school_admin', 'teacher', 'student', 'parent']::public.app_role[]
        )
    )
  );

drop policy if exists "material_region_assets_manage_staff" on public.material_region_assets;
create policy "material_region_assets_manage_staff"
  on public.material_region_assets
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.material_page_regions r
      join public.material_pages mp
        on mp.id = r.material_page_id
      join public.materials m
        on m.id = mp.material_id
      where r.id = material_region_assets.region_id
        and public.has_school_role(
          m.school_id,
          array['school_admin', 'teacher']::public.app_role[]
        )
    )
  )
  with check (
    exists (
      select 1
      from public.material_page_regions r
      join public.material_pages mp
        on mp.id = r.material_page_id
      join public.materials m
        on m.id = mp.material_id
      where r.id = material_region_assets.region_id
        and public.has_school_role(
          m.school_id,
          array['school_admin', 'teacher']::public.app_role[]
        )
    )
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'material-pages',
    'material-pages',
    false,
    10485760,
    array[
      'image/jpeg',
      'image/png',
      'image/webp'
    ]
  ),
  (
    'teaching-video',
    'teaching-video',
    false,
    157286400,
    array[
      'video/mp4',
      'video/webm',
      'video/quicktime',
      'video/x-m4v'
    ]
  )
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "material_pages_objects_select_same_school" on storage.objects;
create policy "material_pages_objects_select_same_school"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'material-pages'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher', 'student', 'parent']::public.app_role[]
    )
  );

drop policy if exists "material_pages_objects_insert_staff" on storage.objects;
create policy "material_pages_objects_insert_staff"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'material-pages'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and lower(coalesce(storage.extension(name), '')) = any (
      array['jpg', 'jpeg', 'png', 'webp']
    )
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );

drop policy if exists "material_pages_objects_update_staff" on storage.objects;
create policy "material_pages_objects_update_staff"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'material-pages'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  )
  with check (
    bucket_id = 'material-pages'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );

drop policy if exists "material_pages_objects_delete_staff" on storage.objects;
create policy "material_pages_objects_delete_staff"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'material-pages'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );

drop policy if exists "teaching_video_objects_select_same_school" on storage.objects;
create policy "teaching_video_objects_select_same_school"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'teaching-video'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher', 'student', 'parent']::public.app_role[]
    )
  );

drop policy if exists "teaching_video_objects_insert_staff" on storage.objects;
create policy "teaching_video_objects_insert_staff"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'teaching-video'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and lower(coalesce(storage.extension(name), '')) = any (
      array['mp4', 'webm', 'mov', 'm4v']
    )
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );

drop policy if exists "teaching_video_objects_update_staff" on storage.objects;
create policy "teaching_video_objects_update_staff"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'teaching-video'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  )
  with check (
    bucket_id = 'teaching-video'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );

drop policy if exists "teaching_video_objects_delete_staff" on storage.objects;
create policy "teaching_video_objects_delete_staff"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'teaching-video'
    and coalesce(array_length(storage.foldername(name), 1), 0) > 0
    and public.has_school_role(
      (storage.foldername(name))[1]::uuid,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );
