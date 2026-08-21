create function public.ai_credential_save(
  user_id uuid,
  provider_kind_id uuid,
  model text,
  api_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret_ref uuid;
  v_credential_id uuid;
begin
  v_secret_ref := vault.create_secret(api_key);

  insert into public.ai_user_credentials (user_id, provider_kind_id, model, secret_ref, key_last4)
  values (user_id, provider_kind_id, model, v_secret_ref, right(api_key, 4))
  returning id into v_credential_id;

  return v_credential_id;
end;
$$;

revoke all on function public.ai_credential_save(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.ai_credential_save(uuid, uuid, text, text) to service_role;

create function public.ai_credential_reveal(secret_ref uuid)
returns text
language sql
security definer
set search_path = ''
as $$
  select decrypted_secret from vault.decrypted_secrets where id = secret_ref;
$$;

revoke all on function public.ai_credential_reveal(uuid) from public, anon, authenticated;
grant execute on function public.ai_credential_reveal(uuid) to service_role;

-- vault.secrets não aceita FK para auth.users: sem este gatilho, o cascade
-- de exclusão de conta apaga a credencial e deixa o segredo cifrado órfão
-- no Vault, para sempre.
create function public.handle_ai_credential_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from vault.secrets where id = old.secret_ref;
  return old;
end;
$$;

create trigger ai_credential_deleted_clears_vault
  before delete on public.ai_user_credentials
  for each row
  execute function public.handle_ai_credential_deleted();
