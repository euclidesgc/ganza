create table public.bank_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  item_id text not null unique,
  institution_name text not null,
  status text not null default 'pending' check (status in ('pending', 'connected', 'error', 'disconnected')),
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index bank_connections_user_idx on public.bank_connections (user_id);

alter table public.bank_connections enable row level security;

create policy bank_connections_owner on public.bank_connections
  for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
