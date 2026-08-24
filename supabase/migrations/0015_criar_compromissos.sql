-- Compromisso financeiro é movimento previsível com direção: a regra gera a
-- fila de parcelas/cobranças (`commitment_occurrences`), exatamente como a
-- rotina gera ocorrências. Dinheiro é `bigint` em centavos; a taxa de juros é
-- `numeric` (não dinheiro) e só entra no cálculo determinístico de
-- `/finance-math`, nunca na saída do modelo.
create table public.commitments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  area_id uuid references public.areas (id) on delete set null,
  name text not null check (char_length(btrim(name)) between 1 and 100),
  direction text not null check (direction in ('in', 'out')),
  value_mode text not null
    check (value_mode in ('one_off', 'installment', 'fixed', 'variable')),
  total_amount bigint check (total_amount > 0),
  installments_total integer check (installments_total > 0),
  due_day integer check (due_day between 1 and 31),
  closing_day integer check (closing_day between 1 and 31),
  reminder_days_before integer not null default 3 check (reminder_days_before >= 0),
  interest_rate_monthly numeric,
  amortization_system text check (amortization_system in ('price', 'sac')),
  indexer text,
  outstanding_balance bigint check (outstanding_balance >= 0),
  category_id uuid references public.categories (id) on delete set null,
  status text not null default 'active' check (status in ('active', 'paid', 'archived')),
  started_at date,
  ends_at date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.commitments enable row level security;

create policy commitments_owner on public.commitments
  for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create table public.commitment_occurrences (
  id uuid primary key default gen_random_uuid(),
  commitment_id uuid not null references public.commitments (id) on delete cascade,
  sequence integer not null check (sequence >= 1),
  due_date date not null,
  expected_amount bigint,
  actual_amount bigint,
  estimate_source text check (estimate_source in ('contract', 'average', 'manual')),
  transaction_id uuid references public.transactions (id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending', 'done', 'skipped', 'cancelled', 'missed', 'matched')),
  unique (commitment_id, sequence)
);

alter table public.commitment_occurrences enable row level security;

-- O dono da ocorrência herda do dono do compromisso (padrão da 004).
create policy commitment_occurrences_owner on public.commitment_occurrences
  for all
  using (
    commitment_id in (
      select c.id from public.commitments c where c.user_id = (select auth.uid())
    )
  )
  with check (
    commitment_id in (
      select c.id from public.commitments c where c.user_id = (select auth.uid())
    )
  );

create index commitment_occurrences_due_idx
  on public.commitment_occurrences (commitment_id, due_date);
