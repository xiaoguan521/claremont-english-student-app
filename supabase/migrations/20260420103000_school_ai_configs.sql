create table if not exists public.school_ai_configs (
  school_id uuid primary key references public.schools (id) on delete cascade,
  provider_type text not null default 'openai_compatible',
  provider_label text not null default 'Custom AI',
  base_url text not null,
  model text not null,
  api_key_ciphertext text not null,
  api_key_masked text not null,
  enabled boolean not null default true,
  created_by uuid references auth.users (id),
  updated_by uuid references auth.users (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint school_ai_configs_base_url_check check (length(trim(base_url)) > 0),
  constraint school_ai_configs_model_check check (length(trim(model)) > 0)
);

alter table public.school_ai_configs enable row level security;

drop trigger if exists trg_school_ai_configs_updated_at on public.school_ai_configs;
create trigger trg_school_ai_configs_updated_at
  before update on public.school_ai_configs
  for each row execute procedure public.set_updated_at();
