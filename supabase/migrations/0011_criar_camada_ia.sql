create table public.ai_providers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text not null,
  base_url text not null,
  secret_ref text not null check (secret_ref ~ '^[a-z][a-z0-9_]{2,63}$'),
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.ai_providers enable row level security;

create policy ai_providers_service on public.ai_providers
  for all
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');

create table public.ai_routes (
  task_type text primary key check (
    task_type in (
      'classify_intent',
      'extract_record',
      'bulk_categorize',
      'resolve_reference',
      'transcribe_audio',
      'summarize_period',
      'refine_idea',
      'answer_query',
      'chat_general'
    )
  ),
  provider_id uuid not null references public.ai_providers(id),
  model text not null,
  temperature numeric,
  max_tokens integer,
  fallback_provider_id uuid not null references public.ai_providers(id)
    check (fallback_provider_id <> provider_id)
);

alter table public.ai_routes enable row level security;

create policy ai_routes_service on public.ai_routes
  for all
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');

create table public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  task_type text not null,
  provider_name text not null,
  model text not null,
  status text not null check (status in ('success', 'error', 'refused')),
  prompt_tokens integer,
  completion_tokens integer,
  cost_micros bigint not null default 0 check (cost_micros >= 0),
  latency_ms integer,
  content_sha256 text check (content_sha256 ~ '^[0-9a-f]{64}$'),
  message_id uuid,
  rejection_code text,
  created_at timestamptz not null default now()
);

alter table public.ai_usage enable row level security;

create policy ai_usage_owner on public.ai_usage
  for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
