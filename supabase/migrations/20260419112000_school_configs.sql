create table if not exists public.school_configs (
  school_id uuid primary key references public.schools (id) on delete cascade,
  slug text not null unique,
  app_display_name text not null,
  welcome_title text not null,
  welcome_message text not null,
  theme_key text not null default 'forest',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create or replace function public.handle_new_school_config()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  insert into public.school_configs (
    school_id,
    slug,
    app_display_name,
    welcome_title,
    welcome_message,
    theme_key
  )
  values (
    new.id,
    coalesce(new.code, replace(lower(new.name), ' ', '-')),
    new.name,
    '欢迎来到' || new.name,
    '今天也要认真完成老师布置的英语学习任务。',
    'forest'
  )
  on conflict (school_id) do nothing;

  return new;
end;
$$;

insert into public.school_configs (
  school_id,
  slug,
  app_display_name,
  welcome_title,
  welcome_message,
  theme_key
)
select
  s.id,
  coalesce(s.code, replace(lower(s.name), ' ', '-')),
  s.name,
  '欢迎来到' || s.name,
  '今天也要认真完成老师布置的英语学习任务。',
  'forest'
from public.schools s
on conflict (school_id) do update
set
  slug = excluded.slug,
  app_display_name = excluded.app_display_name,
  welcome_title = excluded.welcome_title,
  welcome_message = excluded.welcome_message;

alter table public.school_configs enable row level security;

drop policy if exists "school_configs_public_read" on public.school_configs;
create policy "school_configs_public_read"
  on public.school_configs
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.schools s
      where s.id = school_id
        and s.status = 'active'
    )
  );

drop policy if exists "school_configs_manage_admin" on public.school_configs;
create policy "school_configs_manage_admin"
  on public.school_configs
  for all
  to authenticated
  using (
    public.has_school_role(
      school_id,
      array['school_admin']::public.app_role[]
    )
  )
  with check (
    public.has_school_role(
      school_id,
      array['school_admin']::public.app_role[]
    )
  );

drop trigger if exists trg_school_configs_updated_at on public.school_configs;
create trigger trg_school_configs_updated_at
  before update on public.school_configs
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_school_insert_default_config on public.schools;
create trigger trg_school_insert_default_config
  after insert on public.schools
  for each row execute procedure public.handle_new_school_config();
