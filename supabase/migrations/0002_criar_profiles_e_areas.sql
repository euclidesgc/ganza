create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  timezone text not null default 'America/Sao_Paulo',
  locale text not null default 'pt-BR',
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy profiles_owner on public.profiles
  for all
  using (id = auth.uid())
  with check (id = auth.uid());

create table public.areas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  slug text not null,
  name text not null,
  icon text,
  color text,
  allowed_types text[] not null default '{}',
  default_view text,
  dashboard_config jsonb not null default '{}'::jsonb,
  is_system boolean not null default false,
  position integer not null default 0,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, slug)
);

alter table public.areas enable row level security;

create policy areas_owner on public.areas
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- A lista de áreas é lida a cada abertura do app, sempre filtrando arquivadas
-- e ordenando por posição.
create index areas_user_position_idx
  on public.areas (user_id, position)
  where archived_at is null;
