create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'app_role') then
    create type public.app_role as enum (
      'school_admin',
      'teacher',
      'student',
      'parent'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'membership_status'
  ) then
    create type public.membership_status as enum (
      'invited',
      'active',
      'disabled'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'material_status'
  ) then
    create type public.material_status as enum (
      'draft',
      'published',
      'archived'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'assignment_status'
  ) then
    create type public.assignment_status as enum (
      'draft',
      'published',
      'closed',
      'archived'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'assignment_item_type'
  ) then
    create type public.assignment_item_type as enum (
      'word',
      'sentence',
      'paragraph'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'submission_status'
  ) then
    create type public.submission_status as enum (
      'draft',
      'uploaded',
      'queued',
      'processing',
      'completed',
      'failed'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'submission_asset_type'
  ) then
    create type public.submission_asset_type as enum (
      'audio',
      'waveform',
      'report_image'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'evaluation_job_status'
  ) then
    create type public.evaluation_job_status as enum (
      'pending',
      'processing',
      'retrying',
      'completed',
      'failed'
    );
  end if;
end $$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text unique,
  status text not null default 'active',
  contact_name text,
  contact_phone text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  phone text,
  status text not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  name text not null,
  grade_label text,
  academic_year text,
  status text not null default 'active',
  start_date date,
  end_date date,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  school_id uuid not null references public.schools (id) on delete cascade,
  class_id uuid references public.classes (id) on delete cascade,
  role public.app_role not null,
  status public.membership_status not null default 'invited',
  invited_by uuid references auth.users (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.materials (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  title text not null,
  description text,
  pdf_path text not null,
  cover_image_path text,
  page_count integer,
  status public.material_status not null default 'draft',
  uploaded_by uuid not null references auth.users (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  material_id uuid references public.materials (id) on delete set null,
  title text not null,
  description text,
  due_at timestamptz,
  status public.assignment_status not null default 'draft',
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.assignment_items (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments (id) on delete cascade,
  sort_order integer not null default 0,
  item_type public.assignment_item_type not null,
  title text,
  prompt_text text not null,
  tts_text text,
  expected_text text,
  start_page integer,
  end_page integer,
  reference_audio_path text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments (id) on delete cascade,
  student_id uuid not null references auth.users (id) on delete cascade,
  status public.submission_status not null default 'draft',
  submitted_at timestamptz,
  latest_score numeric(5, 2),
  latest_feedback text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint submissions_unique_per_student_assignment unique (
    assignment_id,
    student_id
  )
);

create table if not exists public.submission_assets (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.submissions (id) on delete cascade,
  asset_type public.submission_asset_type not null,
  storage_bucket text not null,
  storage_path text not null,
  mime_type text,
  duration_ms integer,
  size_bytes bigint,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.evaluation_jobs (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.submissions (id) on delete cascade,
  provider text not null,
  status public.evaluation_job_status not null default 'pending',
  attempt_count integer not null default 0,
  last_error text,
  request_payload jsonb not null default '{}'::jsonb,
  requested_at timestamptz not null default timezone('utc', now()),
  started_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default timezone('utc', now()),
  constraint evaluation_jobs_unique_submission unique (submission_id)
);

create table if not exists public.evaluation_results (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.submissions (id) on delete cascade,
  job_id uuid references public.evaluation_jobs (id) on delete set null,
  provider text not null,
  overall_score numeric(5, 2),
  pronunciation_score numeric(5, 2),
  fluency_score numeric(5, 2),
  completeness_score numeric(5, 2),
  strengths jsonb not null default '[]'::jsonb,
  improvement_points jsonb not null default '[]'::jsonb,
  encouragement text,
  raw_result jsonb not null default '{}'::jsonb,
  evaluated_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint evaluation_results_unique_submission unique (submission_id)
);

create index if not exists idx_classes_school_id
  on public.classes (school_id);

create index if not exists idx_memberships_user_id
  on public.memberships (user_id);

create index if not exists idx_memberships_school_role
  on public.memberships (school_id, role, status);

create index if not exists idx_memberships_class_role
  on public.memberships (class_id, role, status);

create index if not exists idx_materials_school_id
  on public.materials (school_id, status);

create index if not exists idx_assignments_class_due_at
  on public.assignments (class_id, due_at desc);

create index if not exists idx_assignment_items_assignment_sort
  on public.assignment_items (assignment_id, sort_order);

create index if not exists idx_submissions_student_status
  on public.submissions (student_id, status);

create index if not exists idx_submission_assets_submission_id
  on public.submission_assets (submission_id);

create index if not exists idx_evaluation_jobs_status
  on public.evaluation_jobs (status, requested_at);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', '')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create or replace function public.validate_membership_scope()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  class_school_id uuid;
begin
  if new.class_id is null then
    return new;
  end if;

  select c.school_id
  into class_school_id
  from public.classes c
  where c.id = new.class_id;

  if class_school_id is null then
    raise exception 'Class % does not exist.', new.class_id;
  end if;

  if class_school_id <> new.school_id then
    raise exception 'Membership school_id must match class.school_id.';
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

drop trigger if exists trg_schools_updated_at on public.schools;
create trigger trg_schools_updated_at
  before update on public.schools
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_classes_updated_at on public.classes;
create trigger trg_classes_updated_at
  before update on public.classes
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_memberships_updated_at on public.memberships;
create trigger trg_memberships_updated_at
  before update on public.memberships
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_memberships_validate_scope on public.memberships;
create trigger trg_memberships_validate_scope
  before insert or update on public.memberships
  for each row execute procedure public.validate_membership_scope();

drop trigger if exists trg_materials_updated_at on public.materials;
create trigger trg_materials_updated_at
  before update on public.materials
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_assignments_updated_at on public.assignments;
create trigger trg_assignments_updated_at
  before update on public.assignments
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_assignment_items_updated_at on public.assignment_items;
create trigger trg_assignment_items_updated_at
  before update on public.assignment_items
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_submissions_updated_at on public.submissions;
create trigger trg_submissions_updated_at
  before update on public.submissions
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_evaluation_jobs_updated_at on public.evaluation_jobs;
create trigger trg_evaluation_jobs_updated_at
  before update on public.evaluation_jobs
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_evaluation_results_updated_at on public.evaluation_results;
create trigger trg_evaluation_results_updated_at
  before update on public.evaluation_results
  for each row execute procedure public.set_updated_at();

create or replace function public.has_school_role(
  target_school_id uuid,
  allowed_roles public.app_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.school_id = target_school_id
      and m.status = 'active'
      and m.role = any (allowed_roles)
  );
$$;

create or replace function public.has_class_role(
  target_class_id uuid,
  allowed_roles public.app_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.classes c
    join public.memberships m
      on m.school_id = c.school_id
    where c.id = target_class_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and m.role = any (allowed_roles)
      and (m.class_id is null or m.class_id = target_class_id)
  );
$$;

create or replace function public.can_read_submission(
  target_submission_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.submissions s
    join public.assignments a
      on a.id = s.assignment_id
    where s.id = target_submission_id
      and (
        s.student_id = auth.uid()
        or public.has_class_role(a.class_id, array['school_admin', 'teacher']::public.app_role[])
      )
  );
$$;

alter table public.schools enable row level security;
alter table public.profiles enable row level security;
alter table public.classes enable row level security;
alter table public.memberships enable row level security;
alter table public.materials enable row level security;
alter table public.assignments enable row level security;
alter table public.assignment_items enable row level security;
alter table public.submissions enable row level security;
alter table public.submission_assets enable row level security;
alter table public.evaluation_jobs enable row level security;
alter table public.evaluation_results enable row level security;

drop policy if exists "schools_select_same_school" on public.schools;
create policy "schools_select_same_school"
  on public.schools
  for select
  to authenticated
  using (
    public.has_school_role(
      id,
      array['school_admin', 'teacher', 'student', 'parent']::public.app_role[]
    )
  );

drop policy if exists "profiles_select_self_or_staff" on public.profiles;
create policy "profiles_select_self_or_staff"
  on public.profiles
  for select
  to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1
      from public.memberships viewer
      join public.memberships target
        on target.school_id = viewer.school_id
       and target.user_id = profiles.id
       and target.status = 'active'
      where viewer.user_id = auth.uid()
        and viewer.status = 'active'
        and viewer.role in ('school_admin', 'teacher')
    )
  );

drop policy if exists "profiles_update_self" on public.profiles;
create policy "profiles_update_self"
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists "classes_select_same_school" on public.classes;
create policy "classes_select_same_school"
  on public.classes
  for select
  to authenticated
  using (
    public.has_school_role(
      school_id,
      array['school_admin', 'teacher', 'student', 'parent']::public.app_role[]
    )
  );

drop policy if exists "memberships_select_same_school" on public.memberships;
create policy "memberships_select_same_school"
  on public.memberships
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or public.has_school_role(
      school_id,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );

drop policy if exists "materials_select_same_school" on public.materials;
create policy "materials_select_same_school"
  on public.materials
  for select
  to authenticated
  using (
    public.has_school_role(
      school_id,
      array['school_admin', 'teacher', 'student', 'parent']::public.app_role[]
    )
  );

drop policy if exists "materials_manage_staff" on public.materials;
create policy "materials_manage_staff"
  on public.materials
  for all
  to authenticated
  using (
    public.has_school_role(
      school_id,
      array['school_admin', 'teacher']::public.app_role[]
    )
  )
  with check (
    public.has_school_role(
      school_id,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );

drop policy if exists "assignments_select_class_members" on public.assignments;
create policy "assignments_select_class_members"
  on public.assignments
  for select
  to authenticated
  using (
    public.has_class_role(
      class_id,
      array['school_admin', 'teacher', 'student', 'parent']::public.app_role[]
    )
  );

drop policy if exists "assignments_manage_staff" on public.assignments;
create policy "assignments_manage_staff"
  on public.assignments
  for all
  to authenticated
  using (
    public.has_class_role(
      class_id,
      array['school_admin', 'teacher']::public.app_role[]
    )
  )
  with check (
    public.has_class_role(
      class_id,
      array['school_admin', 'teacher']::public.app_role[]
    )
  );

drop policy if exists "assignment_items_select_class_members" on public.assignment_items;
create policy "assignment_items_select_class_members"
  on public.assignment_items
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.assignments a
      where a.id = assignment_id
        and public.has_class_role(
          a.class_id,
          array['school_admin', 'teacher', 'student', 'parent']::public.app_role[]
        )
    )
  );

drop policy if exists "assignment_items_manage_staff" on public.assignment_items;
create policy "assignment_items_manage_staff"
  on public.assignment_items
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.assignments a
      where a.id = assignment_id
        and public.has_class_role(
          a.class_id,
          array['school_admin', 'teacher']::public.app_role[]
        )
    )
  )
  with check (
    exists (
      select 1
      from public.assignments a
      where a.id = assignment_id
        and public.has_class_role(
          a.class_id,
          array['school_admin', 'teacher']::public.app_role[]
        )
    )
  );

drop policy if exists "submissions_select_owner_or_staff" on public.submissions;
create policy "submissions_select_owner_or_staff"
  on public.submissions
  for select
  to authenticated
  using (
    student_id = auth.uid()
    or public.can_read_submission(id)
  );

drop policy if exists "submissions_insert_student" on public.submissions;
create policy "submissions_insert_student"
  on public.submissions
  for insert
  to authenticated
  with check (
    student_id = auth.uid()
    and exists (
      select 1
      from public.assignments a
      where a.id = assignment_id
        and public.has_class_role(
          a.class_id,
          array['student']::public.app_role[]
        )
    )
  );

drop policy if exists "submissions_update_owner_or_staff" on public.submissions;
create policy "submissions_update_owner_or_staff"
  on public.submissions
  for update
  to authenticated
  using (
    student_id = auth.uid()
    or public.can_read_submission(id)
  )
  with check (
    student_id = auth.uid()
    or public.can_read_submission(id)
  );

drop policy if exists "submission_assets_select_owner_or_staff" on public.submission_assets;
create policy "submission_assets_select_owner_or_staff"
  on public.submission_assets
  for select
  to authenticated
  using (public.can_read_submission(submission_id));

drop policy if exists "submission_assets_insert_owner_or_staff" on public.submission_assets;
create policy "submission_assets_insert_owner_or_staff"
  on public.submission_assets
  for insert
  to authenticated
  with check (public.can_read_submission(submission_id));

drop policy if exists "evaluation_jobs_select_owner_or_staff" on public.evaluation_jobs;
create policy "evaluation_jobs_select_owner_or_staff"
  on public.evaluation_jobs
  for select
  to authenticated
  using (public.can_read_submission(submission_id));

drop policy if exists "evaluation_results_select_owner_or_staff" on public.evaluation_results;
create policy "evaluation_results_select_owner_or_staff"
  on public.evaluation_results
  for select
  to authenticated
  using (public.can_read_submission(submission_id));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'materials',
    'materials',
    false,
    52428800,
    array['application/pdf']
  ),
  (
    'submission-audio',
    'submission-audio',
    false,
    15728640,
    array['audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/x-wav', 'audio/aac']
  )
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

comment on table public.memberships is
  'Memberships model school-level and class-level roles. Students should have class_id, school admins can keep class_id null.';

comment on table public.assignment_items is
  'Structured reading prompts configured by teachers. Do not rely on runtime PDF parsing for the first release.';

comment on table public.evaluation_jobs is
  'Async speech-evaluation queue table. Workers or Edge Functions should move jobs through pending/processing/retrying/completed/failed.';
