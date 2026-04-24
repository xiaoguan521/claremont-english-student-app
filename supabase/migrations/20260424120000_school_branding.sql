alter table public.school_configs
  add column if not exists brand_name text not null default '',
  add column if not exists logo_url text not null default '';
