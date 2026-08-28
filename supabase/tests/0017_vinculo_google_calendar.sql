-- Prova de comportamento da migration 0017 (vínculo Google Calendar), contra
-- um banco com 0001--0017 já aplicadas e o bootstrap de `auth` do CI. Roda
-- com `psql -v ON_ERROR_STOP=1`: qualquer `raise exception` aborta o script
-- com saída não-zero. Tudo corre dentro de uma transação revertida ao final,
-- para não deixar resíduo no banco descartável do CI.
--
-- `:'variavel'` do psql não é substituído dentro de corpo `$$ ... $$`: por
-- isso as asserções que dependem de valor capturado por `\gset` chamam
-- `pg_temp.assert(...)` como comando de topo, em vez de viver num `do $$`.

begin;

create function pg_temp.assert(condition boolean, message text)
returns void
language plpgsql
as $$
begin
  if not condition then
    raise exception '%', message;
  end if;
end;
$$;

insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-00000000000a', 'usuario-a@teste.ganza'),
  ('b0000000-0000-0000-0000-00000000000b', 'usuario-b@teste.ganza');

-- === Bloco de consumo/purge ===================================================

-- 1) Consumir um state válido remove a linha e o segredo PKCE do Vault.
set local role authenticated;
set local request.jwt.claims to '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select public.google_oauth_authorization_start(
  extensions.digest('state-consumo-1', 'sha256'), 'verifier-consumo-1', 'https://app/callback'
) as v_authorization_consumo_1 \gset
reset role;

select pkce_secret_ref as v_pkce_ref_consumo_1
from public.google_oauth_authorizations
where state_sha256 = extensions.digest('state-consumo-1', 'sha256') \gset

select pg_temp.assert(
  exists (select 1 from vault.secrets where id = :'v_pkce_ref_consumo_1'::uuid),
  'setup: segredo PKCE do consumo-1 deveria existir antes do consumo'
);

set local role service_role;
select public.google_oauth_authorization_complete_callback(
  extensions.digest('state-consumo-1', 'sha256'), 'google-sub-consumo-1', 'primary-consumo-1', 'refresh-consumo-1'
) as v_connection_consumo_1 \gset
reset role;

select pg_temp.assert(
  not exists (select 1 from public.google_oauth_authorizations where state_sha256 = extensions.digest('state-consumo-1', 'sha256')),
  'consumir o state deveria remover a linha de google_oauth_authorizations'
);
select pg_temp.assert(
  not exists (select 1 from vault.secrets where id = :'v_pkce_ref_consumo_1'::uuid),
  'consumir o state deveria remover o segredo PKCE do Vault'
);

-- 2) O purge de state vencido faz a mesma limpeza (linha + segredo).
select vault.create_secret('verifier-purge-direto-1') as v_pkce_ref_purge_direto_1 \gset

insert into public.google_oauth_authorizations
  (user_id, state_sha256, pkce_secret_ref, redirect_uri, created_at, expires_at)
values (
  'a0000000-0000-0000-0000-00000000000a',
  extensions.digest('state-purge-direto-1', 'sha256'),
  :'v_pkce_ref_purge_direto_1'::uuid,
  'https://app/callback',
  now() - interval '20 minutes',
  now() - interval '10 minutes'
);

select public.google_oauth_authorizations_purge_expired() as v_purge_direto_count \gset

select pg_temp.assert(
  not exists (select 1 from public.google_oauth_authorizations where state_sha256 = extensions.digest('state-purge-direto-1', 'sha256')),
  'o purge deveria remover a linha de state vencido'
);
select pg_temp.assert(
  not exists (select 1 from vault.secrets where id = :'v_pkce_ref_purge_direto_1'::uuid),
  'o purge deveria remover o segredo PKCE do state vencido'
);

-- 3) Iniciar OAuth executa o purge antes de inserir o novo state: um state
-- vencido preexistente desaparece na chamada de `google_oauth_authorization_start`.
select vault.create_secret('verifier-purge-antes-de-iniciar') as v_pkce_ref_purge_antes \gset

insert into public.google_oauth_authorizations
  (user_id, state_sha256, pkce_secret_ref, redirect_uri, created_at, expires_at)
values (
  'a0000000-0000-0000-0000-00000000000a',
  extensions.digest('state-purge-antes-de-iniciar-expirado', 'sha256'),
  :'v_pkce_ref_purge_antes'::uuid,
  'https://app/callback',
  now() - interval '20 minutes',
  now() - interval '10 minutes'
);

set local role authenticated;
set local request.jwt.claims to '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select public.google_oauth_authorization_start(
  extensions.digest('state-purge-antes-de-iniciar-novo', 'sha256'), 'verifier-purge-antes-novo', 'https://app/callback'
) as v_authorization_purge_antes_novo \gset
reset role;

select pg_temp.assert(
  not exists (select 1 from public.google_oauth_authorizations where state_sha256 = extensions.digest('state-purge-antes-de-iniciar-expirado', 'sha256')),
  'iniciar OAuth deveria ter purgado o state vencido preexistente antes de inserir o novo'
);
select pg_temp.assert(
  not exists (select 1 from vault.secrets where id = :'v_pkce_ref_purge_antes'::uuid),
  'o purge disparado por iniciar OAuth deveria ter removido o segredo do state vencido'
);
select pg_temp.assert(
  exists (select 1 from public.google_oauth_authorizations where state_sha256 = extensions.digest('state-purge-antes-de-iniciar-novo', 'sha256')),
  'o novo state deveria ter sido inserido após o purge'
);

-- 4) A rotina de purge está agendada: existe job em cron.job cujo command
-- invoca a função de purge.
select pg_temp.assert(
  exists (select 1 from cron.job where command ~* 'public\.google_oauth_authorizations_purge_expired'),
  'esperava um job em cron.job agendando o purge de states vencidos'
);

-- === Bloco de autorização ======================================================

-- Fixture: usuário A vincula uma conexão real, para servir de alvo aos
-- testes de isolamento entre usuários.
set local role authenticated;
set local request.jwt.claims to '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select public.google_calendar_connection_save('google-sub-a', 'primary-a', 'refresh-a') as v_connection_a \gset
reset role;

-- 5) Um JWT não grava nem consulta relação de outro usuário.
set local role authenticated;
set local request.jwt.claims to '{"sub":"b0000000-0000-0000-0000-00000000000b","role":"authenticated"}';

do $$
declare
  v_visible_para_b integer;
begin
  select count(*) into v_visible_para_b from public.google_calendar_connections;
  if v_visible_para_b <> 0 then
    raise exception 'usuário B enxergou % linha(s) da conexão de outro usuário', v_visible_para_b;
  end if;
end;
$$;

do $$
begin
  update public.google_calendar_connections
    set status = 'reconnect_required'
    where user_id = 'a0000000-0000-0000-0000-00000000000a';
  raise exception 'usuário B não deveria conseguir escrever diretamente na tabela de conexões';
exception
  when insufficient_privilege then
    null; -- esperado: authenticated não tem grant de UPDATE na tabela
end;
$$;

do $$
begin
  perform 1 from public.google_oauth_authorizations limit 1;
  raise exception 'nenhum papel deveria ter SELECT direto em google_oauth_authorizations';
exception
  when insufficient_privilege then
    null; -- esperado: nem o dono do state tem select direto na tabela
end;
$$;

reset role;

-- 6) `user_id` é derivado de auth.uid() dentro do banco, não escolhido pelo
-- chamador: a conexão criada pelo usuário A pertence a A, mesmo sem nenhum
-- parâmetro de identidade na chamada.
select pg_temp.assert(
  (select user_id from public.google_calendar_connections where id = :'v_connection_a'::uuid)
    = 'a0000000-0000-0000-0000-00000000000a'::uuid,
  'a conexão deveria pertencer a quem chamou a RPC sob o próprio JWT'
);

-- 7) Não existe RPC interativa que aceite p_user_id.
select pg_temp.assert(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'google\_%'
      and pg_get_function_arguments(p.oid) ~ 'p_user_id'
  ),
  'há RPC aceitando p_user_id, contornando auth.uid()'
);

-- 8) `service_role` não tem SELECT/INSERT/UPDATE/DELETE direto nas duas
-- tabelas: só chega a elas por RPC security definer.
select pg_temp.assert(
  not (
    has_table_privilege('service_role', 'public.google_calendar_connections', 'SELECT')
    or has_table_privilege('service_role', 'public.google_calendar_connections', 'INSERT')
    or has_table_privilege('service_role', 'public.google_calendar_connections', 'UPDATE')
    or has_table_privilege('service_role', 'public.google_calendar_connections', 'DELETE')
  ),
  'service_role não deveria ter CRUD direto em google_calendar_connections'
);
select pg_temp.assert(
  not (
    has_table_privilege('service_role', 'public.google_oauth_authorizations', 'SELECT')
    or has_table_privilege('service_role', 'public.google_oauth_authorizations', 'INSERT')
    or has_table_privilege('service_role', 'public.google_oauth_authorizations', 'UPDATE')
    or has_table_privilege('service_role', 'public.google_oauth_authorizations', 'DELETE')
  ),
  'service_role não deveria ter CRUD direto em google_oauth_authorizations'
);

-- 9) A ponte pública do callback aceita somente o state: nem
-- `prepare_callback` nem `complete_callback` recebem identidade do chamador.
select pg_temp.assert(
  (
    select pg_get_function_arguments(oid)
    from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname = 'google_oauth_authorization_prepare_callback'
  ) = 'p_state_sha256 bytea',
  'prepare_callback deveria aceitar somente p_state_sha256'
);
select pg_temp.assert(
  (
    select pg_get_function_arguments(oid)
    from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname = 'google_oauth_authorization_complete_callback'
  ) = 'p_state_sha256 bytea, p_google_subject text, p_primary_calendar_id text, p_secret_value text',
  'complete_callback não deveria aceitar identidade do chamador'
);

rollback;
