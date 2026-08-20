alter table public.profiles
  add column display_name text;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, new.raw_user_meta_data ->> 'display_name');

  insert into public.areas (user_id, slug, name, is_system, position) values
    (new.id, 'rotina-pessoal',      'Rotina pessoal',      true, 0),
    (new.id, 'rotina-profissional', 'Rotina profissional', true, 1),
    (new.id, 'alimentacao',         'Alimentação',         true, 2),
    (new.id, 'objetivos',           'Objetivos',           true, 3);

  return new;
end;
$$;
