# T5.1 — provas no banco de `public.bank_connections`

Data: 2026-08-21. Migration: `supabase/migrations/0009_criar_conexoes_bancarias.sql`.
Banco recriado do zero com `bash scripts/local-supabase.sh reset` (exit code `0`),
provas rodadas via `docker compose -f infra/local/docker-compose.yml exec -T db psql`
com SQL redirecionado por arquivo (`< arquivo.sql`), nunca heredoc.

## 1. Tabela existe

```
$ docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres -tAc "select to_regclass('public.bank_connections') is not null"
t
```

## 2. RLS ligada e política de dono

```
$ docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres -tAc "select rowsecurity from pg_tables where schemaname='public' and tablename='bank_connections'"
t

$ docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres -tAc "select qual, with_check from pg_policies where tablename='bank_connections'"
(user_id = ( SELECT uid() AS uid))|(user_id = ( SELECT uid() AS uid))
```

**Nota sobre o texto literal esperado.** O papel `supabase_admin` (imagem pinada
`supabase/postgres:15.8.1.085`) traz `auth` no `search_path` por padrão
(`"$user", public, auth, extensions`), então o Postgres decompila `auth.uid()`
sem o prefixo de schema quando ele não é ambíguo — o mesmo acontece hoje com a
política já existente de `ai_user_credentials` (0007), consultada com o mesmo
comando:

```
$ docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres -tAc "select qual from pg_policies where tablename='ai_user_credentials'"
(user_id = ( SELECT uid() AS uid))
```

Ou seja: a política de `bank_connections` é **idêntica**, byte a byte, à de
`ai_user_credentials` sob a mesma sessão — a convenção do subselect
`(select auth.uid())` foi seguida corretamente. Forçando `search_path` para
excluir `auth` (`set search_path to public;`), a mesma política decompila com
o prefixo, batendo com o texto do DoD:

```
$ docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres -tAc "set search_path to public; select qual from pg_policies where tablename='ai_user_credentials'"
SET
(user_id = ( SELECT auth.uid() AS uid))
```

Ambas as tabelas passam pela mesma lente — o resultado depende só do
`search_path` da sessão, não da migration.

## 3. Status é conjunto fechado — check constraint

Transação em `supabase/migrations` local, encerrada por `rollback`; os quatro
valores válidos (`pending`, `connected`, `error`, `disconnected`) são aceitos,
o quinto (`invalido`) é recusado, e o `rollback` final devolve a tabela vazia:

```
$ docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres < t5_1_check_constraint.sql
BEGIN
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
SAVEPOINT
ERROR:  new row for relation "bank_connections" violates check constraint "bank_connections_status_check"
DETAIL:  Failing row contains (ae4262f0-6174-4bf1-81f8-1a5af423b50d, eafdfb93-aa6c-470c-893a-6096480c4c94, chk-invalido, Banco Teste, invalido, null, 2026-08-21 18:57:58.997735+00, 2026-08-21 18:57:58.997735+00).
ROLLBACK
ROLLBACK
 tabela_apos_rollback
----------------------
                    0
(1 row)
```

## 4. `item_id` é único

Segunda transação, também encerrada por `rollback`; o segundo `insert` do
mesmo `item_id` é recusado por `duplicate key value violates unique constraint`:

```
$ docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres < t5_1_unique_constraint.sql
BEGIN
INSERT 0 1
SAVEPOINT
ERROR:  duplicate key value violates unique constraint "bank_connections_item_id_key"
DETAIL:  Key (item_id)=(dup-item-001) already exists.
ROLLBACK
ROLLBACK
 tabela_apos_rollback
----------------------
                    0
(1 row)
```

## 5. Isolamento por `user_id`

Partindo da tabela vazia (fim da prova 4), insere uma linha para o usuário A
(`eafdfb93-aa6c-470c-893a-6096480c4c94`, seed do banco local), confirma que
`auth.uid()` resolve para A via `request.jwt.claims`, e então confere a
contagem sob `role authenticated` primeiro como B (usuário sem linha),
depois como A:

```
$ docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres < t5_1_isolation_insert_a.sql
INSERT 0 1

$ docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres < t5_1_isolation_auth_uid_a.sql
BEGIN
SET
                 uid
--------------------------------------
 eafdfb93-aa6c-470c-893a-6096480c4c94
(1 row)

COMMIT

$ docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres < t5_1_isolation_count_b.sql
BEGIN
SET
SET
 count
-------
     0
(1 row)

COMMIT

$ docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres < t5_1_isolation_count_a.sql
BEGIN
SET
SET
 count
-------
     1
(1 row)

COMMIT
```

## 6. Apagar o usuário apaga a conexão (cascade)

Com a linha de A ainda no banco (prova 5), apagar o usuário em `auth.users`
zera a contagem de `bank_connections` desse `user_id`:

```
$ docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres < t5_1_cascade_delete.sql
DELETE 1
 count
-------
     0
(1 row)
```

## Restauração do banco local

As provas 3 a 6 alteram estado (a 6 apaga o usuário seed). Como a stack Docker
é compartilhada com outras frentes, o banco foi devolvido a um estado limpo e
com as migrations aplicadas rodando `bash scripts/local-supabase.sh reset`
mais uma vez ao final (exit code `0`).
