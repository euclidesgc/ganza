-- O perfil e as áreas padrão nascem com o usuário. Fazer isso no app deixaria
-- uma janela em que a sessão existe e o perfil não, e todo caminho de leitura
-- precisaria tratar o nulo.
create function public.handle_new_user()
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

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
