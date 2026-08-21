create table public.ai_provider_kinds (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  created_at timestamptz not null default now()
);

alter table public.ai_provider_kinds enable row level security;

create policy ai_provider_kinds_readable on public.ai_provider_kinds
  for select to authenticated using (true);

insert into public.ai_provider_kinds (slug, name) values
  ('gemini', 'Google Gemini'),
  ('openai', 'OpenAI'),
  ('anthropic', 'Anthropic Claude');

create table public.ai_user_credentials (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  provider_kind_id uuid not null references public.ai_provider_kinds (id),
  model text not null,
  secret_ref uuid not null,
  key_last4 text not null check (char_length(key_last4) = 4),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, provider_kind_id)
);

create index ai_user_credentials_user_idx on public.ai_user_credentials (user_id);

alter table public.ai_user_credentials enable row level security;

create policy ai_user_credentials_owner on public.ai_user_credentials
  for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
