-- Rotinas geram ocorrências: a regra (`routines`) produz a fila
-- (`routine_occurrences`) e cada movimento fica no log (`occurrence_events`).
-- Adiar move a data da MESMA ocorrência (unique (routine_id, sequence) barra a
-- geração duplicada) e loga o evento, para "quantas vezes lavei roupa em
-- agosto" continuar respondível.
create table public.routines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  area_id uuid references public.areas (id) on delete set null,
  name text not null check (char_length(btrim(name)) between 1 and 100),
  recurrence_mode text not null
    check (recurrence_mode in ('calendar', 'interval_from_completion')),
  recurrence_rule integer check (recurrence_rule between 1 and 7),
  interval_days integer check (interval_days > 0),
  reminder_days_before integer not null default 0 check (reminder_days_before >= 0),
  notify_until_days integer not null default 3 check (notify_until_days >= 0),
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index routines_user_name_idx
  on public.routines (user_id, lower(btrim(name)));

alter table public.routines enable row level security;

create policy routines_owner on public.routines
  for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create table public.routine_occurrences (
  id uuid primary key default gen_random_uuid(),
  routine_id uuid not null references public.routines (id) on delete cascade,
  sequence integer not null check (sequence >= 1),
  due_date date not null,
  completed_at timestamptz,
  status text not null default 'pending'
    check (status in ('pending', 'done', 'postponed', 'skipped', 'cancelled', 'missed')),
  unique (routine_id, sequence)
);

alter table public.routine_occurrences enable row level security;

-- O dono da ocorrência herda do dono da rotina: sem coluna user_id própria, a
-- RLS resolve pela FK até `routines.user_id`.
create policy routine_occurrences_owner on public.routine_occurrences
  for all
  using (
    routine_id in (select r.id from public.routines r where r.user_id = (select auth.uid()))
  )
  with check (
    routine_id in (select r.id from public.routines r where r.user_id = (select auth.uid()))
  );

create table public.occurrence_events (
  id uuid primary key default gen_random_uuid(),
  routine_id uuid not null references public.routines (id) on delete cascade,
  occurrence_id uuid references public.routine_occurrences (id) on delete cascade,
  event text not null check (event in ('postponed', 'skipped', 'done', 'cancelled')),
  from_date date,
  to_date date,
  created_at timestamptz not null default now()
);

alter table public.occurrence_events enable row level security;

create policy occurrence_events_owner on public.occurrence_events
  for all
  using (
    routine_id in (select r.id from public.routines r where r.user_id = (select auth.uid()))
  )
  with check (
    routine_id in (select r.id from public.routines r where r.user_id = (select auth.uid()))
  );

create index routine_occurrences_due_idx
  on public.routine_occurrences (routine_id, due_date);
