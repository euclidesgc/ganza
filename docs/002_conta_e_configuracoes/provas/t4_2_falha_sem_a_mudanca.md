# T4.2 — prova de que o gatilho falha sem a mudança

Data: 2026-08-21. Alvo: `supabase/migrations/0008_criar_ponte_de_vault_das_credenciais_de_ia.sql`,
removendo o gatilho `ai_credential_deleted_clears_vault` e a função
`public.handle_ai_credential_deleted()`, aplicando a árvore num
`scripts/local-supabase.sh reset`, refazendo o caminho da credencial, e
revertendo em seguida — a árvore ficou como estava antes desta prova.

## Diff aplicado (e desfeito) na migration

```diff
diff --git a/supabase/migrations/0008_criar_ponte_de_vault_das_credenciais_de_ia.sql b/supabase/migrations/0008_criar_ponte_de_vault_das_credenciais_de_ia.sql
index fdfe16a..783f0b4 100644
--- a/supabase/migrations/0008_criar_ponte_de_vault_das_credenciais_de_ia.sql
+++ b/supabase/migrations/0008_criar_ponte_de_vault_das_credenciais_de_ia.sql
@@ -37,23 +37,3 @@ $$;

 revoke all on function public.ai_credential_reveal(uuid) from public, anon, authenticated;
 grant execute on function public.ai_credential_reveal(uuid) to service_role;
-
--- vault.secrets não aceita FK para auth.users: sem este gatilho, o cascade
--- de exclusão de conta apaga a credencial e deixa o segredo cifrado órfão
--- no Vault, para sempre.
-create function public.handle_ai_credential_deleted()
-returns trigger
-language plpgsql
-security definer
-set search_path = ''
-as $$
-begin
-  delete from vault.secrets where id = old.secret_ref;
-  return old;
-end;
-$$;
-
-create trigger ai_credential_deleted_clears_vault
-  before delete on public.ai_user_credentials
-  for each row
-  execute function public.handle_ai_credential_deleted();
```

## Comandos, da raiz do repositório

```
scripts/local-supabase.sh reset
docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres -c "insert into auth.users (id, email) values ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 't4-2@ganza.local')"
docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres -tAc "select public.ai_credential_save('dddddddd-dddd-4ddd-8ddd-dddddddddddd', (select id from public.ai_provider_kinds where slug = 'gemini'), 'gemini-2.0-flash', 'sk-test-ganza-0008-ABCD')"
docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres -tA -c "create temp table ref_credencial as select secret_ref from public.ai_user_credentials where user_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'; select 'antes_credencial=' || count(*) from vault.secrets where id in (select secret_ref from ref_credencial); delete from public.ai_user_credentials where user_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'; select 'depois_credencial=' || count(*) from vault.secrets where id in (select secret_ref from ref_credencial);"
```

## Saída (vermelha, com o gatilho removido)

```
antes_credencial=1
depois_credencial=1
```

O segredo cifrado sobrevive à exclusão da credencial — órfão no Vault,
para sempre — exatamente o defeito que o gatilho existe para fechar.

## Restauração

O diff acima foi revertido logo em seguida por edição reversa (nunca
`git stash`) — `git diff supabase/migrations/0008_criar_ponte_de_vault_das_credenciais_de_ia.sql`
não mostra nenhuma alteração pendente neste arquivo, e o
`scripts/local-supabase.sh reset` posterior aplica a migration completa,
com o gatilho de volta, e o caminho da credencial volta a produzir
`antes_credencial=1` seguido de `depois_credencial=0`.
