create table public.google_calendar_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  google_subject text not null check (char_length(btrim(google_subject)) between 1 and 255),
  primary_calendar_id text not null check (char_length(btrim(primary_calendar_id)) between 1 and 1024),
  refresh_secret_ref uuid not null,
  status text not null default 'active' check (status in ('active', 'reconnect_required')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_connected_at timestamptz not null default now(),
  unique (user_id)
);

alter table public.google_calendar_connections enable row level security;

create policy google_calendar_connections_owner on public.google_calendar_connections
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create table public.google_oauth_authorizations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  state_sha256 bytea not null unique check (octet_length(state_sha256) = 32),
  pkce_secret_ref uuid not null,
  redirect_uri text not null check (char_length(btrim(redirect_uri)) between 1 and 2048),
  expires_at timestamptz not null default (now() + interval '10 minutes'),
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);

alter table public.google_oauth_authorizations enable row level security;

create policy google_oauth_authorizations_owner on public.google_oauth_authorizations
  for all
  using (false and (select auth.uid()) = user_id)
  with check (false and (select auth.uid()) = user_id);

revoke all on table public.google_calendar_connections from public, anon, authenticated, service_role;
revoke all on table public.google_oauth_authorizations from public, anon, authenticated, service_role;
grant select (id, status, primary_calendar_id, created_at, updated_at, last_connected_at)
  on table public.google_calendar_connections to authenticated;

create function public.google_calendar_connection_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger google_calendar_connection_updates_timestamp
  before update on public.google_calendar_connections
  for each row
  execute function public.google_calendar_connection_touch_updated_at();

create function public.google_oauth_authorizations_purge_expired()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted integer;
begin
  delete from public.google_oauth_authorizations
  where expires_at <= now();

  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.google_oauth_authorizations_purge_expired() from public, anon, authenticated;
grant execute on function public.google_oauth_authorizations_purge_expired() to service_role;

-- O purge no início de `google_oauth_authorization_start` só roda quando
-- alguém volta a autorizar; sem agendamento, quem vincula uma vez e nunca
-- mais volta deixa state e segredo PKCE no Vault sem limite de tempo (CHG-002
-- em docs/007_agenda/changes.md). `cron.schedule` com nome fixo substitui o
-- job existente em vez de duplicá-lo, então reaplicar esta migration é seguro.
select cron.schedule(
  'google_oauth_authorizations_purge_expired',
  '*/5 * * * *',
  $$select public.google_oauth_authorizations_purge_expired();$$
);

create function public.google_oauth_authorization_start(
  p_state_sha256 bytea,
  p_secret_value text,
  p_redirect_uri text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_secret_ref uuid;
  v_authorization_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  perform public.google_oauth_authorizations_purge_expired();
  v_secret_ref := vault.create_secret(p_secret_value);

  insert into public.google_oauth_authorizations (
    user_id,
    state_sha256,
    pkce_secret_ref,
    redirect_uri
  )
  values (v_user_id, p_state_sha256, v_secret_ref, p_redirect_uri)
  returning id into v_authorization_id;

  return v_authorization_id;
end;
$$;

revoke all on function public.google_oauth_authorization_start(bytea, text, text) from public, anon, service_role;
grant execute on function public.google_oauth_authorization_start(bytea, text, text) to authenticated;

create function public.google_calendar_connection_save(
  p_google_subject text,
  p_primary_calendar_id text,
  p_secret_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_secret_ref uuid;
  v_connection_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  v_secret_ref := vault.create_secret(p_secret_value);

  insert into public.google_calendar_connections (
    user_id,
    google_subject,
    primary_calendar_id,
    refresh_secret_ref,
    status,
    last_connected_at
  )
  values (
    v_user_id,
    p_google_subject,
    p_primary_calendar_id,
    v_secret_ref,
    'active',
    now()
  )
  on conflict (user_id) do update
    set google_subject = excluded.google_subject,
        primary_calendar_id = excluded.primary_calendar_id,
        refresh_secret_ref = excluded.refresh_secret_ref,
        status = 'active',
        last_connected_at = now()
  returning id into v_connection_id;

  return v_connection_id;
end;
$$;

revoke all on function public.google_calendar_connection_save(text, text, text) from public, anon, service_role;
grant execute on function public.google_calendar_connection_save(text, text, text) to authenticated;

create function public.google_calendar_connection_secret_reveal(p_connection_id uuid)
returns text
language sql
security definer
set search_path = ''
as $$
  select vault.decrypted_secrets.decrypted_secret
  from public.google_calendar_connections
  join vault.decrypted_secrets
    on vault.decrypted_secrets.id = public.google_calendar_connections.refresh_secret_ref
  where public.google_calendar_connections.id = p_connection_id;
$$;

revoke all on function public.google_calendar_connection_secret_reveal(uuid) from public, anon, authenticated;
grant execute on function public.google_calendar_connection_secret_reveal(uuid) to service_role;

create function public.google_oauth_authorization_prepare_callback(
  p_state_sha256 bytea
)
returns table (
  secret_value text,
  redirect_uri text
)
language sql
security definer
set search_path = ''
as $$
  select vault.decrypted_secrets.decrypted_secret, public.google_oauth_authorizations.redirect_uri
  from public.google_oauth_authorizations
  join vault.decrypted_secrets
    on vault.decrypted_secrets.id = public.google_oauth_authorizations.pkce_secret_ref
  where public.google_oauth_authorizations.state_sha256 = p_state_sha256
    and public.google_oauth_authorizations.expires_at > now();
$$;

revoke all on function public.google_oauth_authorization_prepare_callback(bytea) from public, anon, authenticated;
grant execute on function public.google_oauth_authorization_prepare_callback(bytea) to service_role;

create function public.google_oauth_authorization_complete_callback(
  p_state_sha256 bytea,
  p_google_subject text,
  p_primary_calendar_id text,
  p_secret_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_secret_ref uuid;
  v_connection_id uuid;
begin
  delete from public.google_oauth_authorizations
  where state_sha256 = p_state_sha256
    and expires_at > now()
  returning user_id into v_user_id;

  if not found then
    raise exception 'authorization state is invalid or expired' using errcode = '22023';
  end if;

  v_secret_ref := vault.create_secret(p_secret_value);

  insert into public.google_calendar_connections (
    user_id,
    google_subject,
    primary_calendar_id,
    refresh_secret_ref,
    status,
    last_connected_at
  )
  values (
    v_user_id,
    p_google_subject,
    p_primary_calendar_id,
    v_secret_ref,
    'active',
    now()
  )
  on conflict (user_id) do update
    set google_subject = excluded.google_subject,
        primary_calendar_id = excluded.primary_calendar_id,
        refresh_secret_ref = excluded.refresh_secret_ref,
        status = 'active',
        last_connected_at = now()
  returning id into v_connection_id;

  return v_connection_id;
end;
$$;

revoke all on function public.google_oauth_authorization_complete_callback(bytea, text, text, text) from public, anon, authenticated;
grant execute on function public.google_oauth_authorization_complete_callback(bytea, text, text, text) to service_role;

create function public.google_oauth_authorization_discard_callback(p_state_sha256 bytea)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.google_oauth_authorizations
  where state_sha256 = p_state_sha256;

  return found;
end;
$$;

revoke all on function public.google_oauth_authorization_discard_callback(bytea) from public, anon, authenticated;
grant execute on function public.google_oauth_authorization_discard_callback(bytea) to service_role;

create function public.google_calendar_connection_secret_cleanup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    delete from vault.secrets where id = old.refresh_secret_ref;
    return old;
  end if;

  if old.refresh_secret_ref is distinct from new.refresh_secret_ref then
    delete from vault.secrets where id = old.refresh_secret_ref;
  end if;

  return new;
end;
$$;

create trigger google_calendar_connection_deleted_clears_vault
  before delete on public.google_calendar_connections
  for each row
  execute function public.google_calendar_connection_secret_cleanup();

create trigger google_calendar_connection_secret_replaced_clears_vault
  before update of refresh_secret_ref on public.google_calendar_connections
  for each row
  execute function public.google_calendar_connection_secret_cleanup();

create function public.google_oauth_authorization_secret_cleanup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    delete from vault.secrets where id = old.pkce_secret_ref;
    return old;
  end if;

  if old.pkce_secret_ref is distinct from new.pkce_secret_ref then
    delete from vault.secrets where id = old.pkce_secret_ref;
  end if;

  return new;
end;
$$;

create trigger google_oauth_authorization_deleted_clears_vault
  before delete on public.google_oauth_authorizations
  for each row
  execute function public.google_oauth_authorization_secret_cleanup();

create trigger google_oauth_authorization_secret_replaced_clears_vault
  before update of pkce_secret_ref on public.google_oauth_authorizations
  for each row
  execute function public.google_oauth_authorization_secret_cleanup();

alter table public.proposed_actions
  drop constraint proposed_actions_kind_check;

alter table public.proposed_actions
  add constraint proposed_actions_kind_check check (
    kind in (
      'create_transaction',
      'create_task',
      'create_note',
      'create_routine',
      'create_commitment',
      'attach_document',
      'create_calendar_event',
      'reschedule_calendar_event'
    )
  );
