-- Categorias de transação e o aprendizado por correção. `categories` é a
-- taxonomia do usuário; `category_hints` guarda "descrição normalizada →
-- categoria" a partir de correções explícitas — nunca da saída do modelo
-- (FD-011). A chave normalizada tem charset fechado `[a-z0-9 ]` e teto de 64
-- caracteres, para que um nome de estabelecimento longo com instrução embutida
-- vire texto inerte antes de virar chave.
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 100),
  created_at timestamptz not null default now()
);

create unique index categories_user_name_idx
  on public.categories (user_id, lower(btrim(name)));

alter table public.categories enable row level security;

create policy categories_owner on public.categories
  for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

alter table public.transactions
  add column category_id uuid references public.categories (id) on delete set null;

create table public.category_hints (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  normalized_description text not null
    check (normalized_description ~ '^[a-z0-9 ]{1,64}$'),
  category_id uuid not null references public.categories (id) on delete cascade,
  hits integer not null default 1 check (hits >= 1),
  updated_at timestamptz not null default now(),
  unique (user_id, normalized_description)
);

alter table public.category_hints enable row level security;

create policy category_hints_owner on public.category_hints
  for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create index category_hints_user_desc_idx
  on public.category_hints (user_id, normalized_description);

-- Semeia as categorias padrão para quem já existia antes desta migration; o
-- handle_new_user abaixo passa a semear para quem nascer depois.
insert into public.categories (user_id, name)
select u.id, c.name
from auth.users u
cross join (values
  ('Alimentação'),
  ('Transporte'),
  ('Moradia'),
  ('Saúde'),
  ('Lazer'),
  ('Educação'),
  ('Contas e serviços'),
  ('Outros')
) as c(name)
on conflict do nothing;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id);

  insert into public.areas (user_id, slug, name, is_system, position) values
    (new.id, 'rotina-pessoal',      'Rotina pessoal',      true, 0),
    (new.id, 'rotina-profissional', 'Rotina profissional', true, 1),
    (new.id, 'alimentacao',         'Alimentação',         true, 2),
    (new.id, 'objetivos',           'Objetivos',           true, 3);

  insert into public.categories (user_id, name) values
    (new.id, 'Alimentação'),
    (new.id, 'Transporte'),
    (new.id, 'Moradia'),
    (new.id, 'Saúde'),
    (new.id, 'Lazer'),
    (new.id, 'Educação'),
    (new.id, 'Contas e serviços'),
    (new.id, 'Outros');

  return new;
end;
$$;
