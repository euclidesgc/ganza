create table public.messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  role text not null default 'user' check (role in ('user', 'assistant')),
  content text not null check (char_length(content) <= 4000),
  origin text not null default 'user_typed'
    check (origin in ('user_typed', 'bank_sync', 'ocr', 'transcript', 'email', 'calendar')),
  media_path text,
  media_type text,
  transcript text,
  created_at timestamptz not null default now()
);

alter table public.messages enable row level security;

create policy messages_owner on public.messages
  for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create table public.proposed_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  message_id uuid not null references public.messages(id) on delete cascade,
  sequence integer not null check (sequence between 1 and 10),
  kind text not null check (
    kind in (
      'create_transaction',
      'create_task',
      'create_note',
      'create_routine',
      'create_commitment',
      'attach_document'
    )
  ),
  payload jsonb not null check (not (payload ? 'user_id')),
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'cancelled')),
  resulting_id uuid,
  resulting_type text,
  created_at timestamptz not null default now()
);

alter table public.proposed_actions enable row level security;

create policy proposed_actions_owner on public.proposed_actions
  for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
