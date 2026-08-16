create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- Dinheiro não se compartimenta por área (docs/plano.md §6.3): a coluna
  -- existe para o chat propor a associação depois, sem migration nova.
  area_id uuid references public.areas (id) on delete set null,
  direction text not null check (direction in ('in', 'out')),
  -- Centavos, nunca float: é a invariante de dinheiro do produto.
  amount bigint not null check (amount > 0),
  description text not null check (char_length(btrim(description)) > 0),
  occurred_at timestamptz not null default now(),
  source text not null default 'manual' check (source in ('manual', 'chat', 'bank_sync')),
  reconciliation_status text not null default 'pending'
    check (reconciliation_status in ('pending', 'matched', 'standalone', 'ignored')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index transactions_user_occurred_idx
  on public.transactions (user_id, occurred_at desc, created_at desc);

alter table public.transactions enable row level security;

create policy transactions_owner on public.transactions
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
