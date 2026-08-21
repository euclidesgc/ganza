# Isolamento entre usuários e RLS de `public.ai_user_credentials`

Prova da **T4.14** — comandos e saídas literais, contra a stack local que
`scripts/local-supabase.sh up` sobe. Nenhum comando abaixo toca servidor
remoto: o único endereço usado é `http://127.0.0.1:54321` (Kong) e a conexão
direta ao Postgres do compose.

Data da execução: 2026-08-21.

## 1. Os dois usuários nascem na própria stack local

Usuário A é o semeado por `scripts/local-supabase.sh up` (função
`create_test_user`), com o JWT já escrito em `infra/local/.runtime.env`:

```
$ cat infra/local/.runtime.env
SUPABASE_URL=http://127.0.0.1:54321
ANON_KEY=$ANON_KEY
JWT_DONO=$JWT_DONO
USER_ID=1ea634c0-fb83-49c3-b454-4427fc2af32c
E2E_EMAIL=e2e@ganza.local
```

`$ANON_KEY` e `$JWT_DONO` acima são os nomes das variáveis — o arquivo real
traz o token JWT completo, que não é colado aqui para nenhum segredo chegar
ao repositório.

Usuário B nasce por signup na mesma stack, com um segundo endereço e a senha
em variável de shell:

```
$ curl -sS -i -X POST http://127.0.0.1:54321/auth/v1/signup \
  -H "apikey: $ANON_KEY" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"usuario-b-t4-14@ganza.local\",\"password\":\"$SENHA_B\"}"
```

saída real observada (corpo resumido às chaves que importam):

```
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 997
Connection: keep-alive
Vary: Origin

{"id":"089cdc7a-96fa-46d9-b730-aef0d0cb0cb5","aud":"","role":"authenticated","email":"usuario-b-t4-14@ganza.local","phone":"", ...}
```

Confirmado direto em `auth.users`, porque `GOTRUE_MAILER_AUTOCONFIRM` é
`'false'` no compose local:

```
$ docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres \
  -c "update auth.users set email_confirmed_at = now() where email = 'usuario-b-t4-14@ganza.local'"
UPDATE 1
```

O JWT de B é assinado pela mesma receita `openssl` da função `jwt()` de
`scripts/local-supabase.sh`, trocando `sub` e `email` pelos de B:

```
$ header='{"alg":"HS256","typ":"JWT"}'
$ payload='{"sub":"089cdc7a-96fa-46d9-b730-aef0d0cb0cb5","email":"usuario-b-t4-14@ganza.local","role":"authenticated","aud":"authenticated","exp":4102444800}'
$ header64=$(printf '%s' "$header" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
$ payload64=$(printf '%s' "$payload" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
$ signature=$(printf '%s' "$header64.$payload64" | openssl dgst -binary -sha256 -hmac "$JWT_SECRET" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
$ JWT_B="$header64.$payload64.$signature"
```

`$JWT_SECRET` acima é o mesmo texto fixo de `infra/local/docker-compose.yml`
— `GOTRUE_JWT_SECRET`, `PGRST_JWT_SECRET` e `SUPABASE_JWT_SECRET` compartilham
o mesmo valor, por isso o token assinado localmente é aceito pela GoTrue,
pelo PostgREST e pela Edge Function. A partir daqui o token só aparece como
`$JWT_B`.

## 2. Pela Edge Function (`ai-credentials`, `action: test`) — 404

A salva a própria credencial primeiro:

```
$ curl -sS -i -X POST http://127.0.0.1:54321/functions/v1/ai-credentials \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $JWT_DONO" \
  -H 'Content-Type: application/json' \
  --data "{\"action\":\"save\",\"provider_kind_id\":\"afca1c4a-6f0f-4317-a706-7a251b565bee\",\"model\":\"gemini-1.5-flash\",\"api_key\":\"$API_KEY_TESTE\"}"
```

saída real:

```
HTTP/1.1 201 Created
Content-Type: application/json
Content-Length: 149
Connection: keep-alive
vary: Accept-Encoding

{"id":"f49bae71-7eee-4da9-9d81-342c582ee71d","provider_kind_id":"afca1c4a-6f0f-4317-a706-7a251b565bee","model":"gemini-1.5-flash","key_last4":"2345"}
```

Com o JWT de B, `credential_id` é o `f49bae71-7eee-4da9-9d81-342c582ee71d` que
A acabou de produzir:

```
$ curl -sS -i -X POST http://127.0.0.1:54321/functions/v1/ai-credentials \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $JWT_B" \
  -H 'Content-Type: application/json' \
  --data '{"action":"test","credential_id":"f49bae71-7eee-4da9-9d81-342c582ee71d"}'
```

saída real:

```
HTTP/1.1 404 Not Found
Content-Type: application/json
Content-Length: 69
Connection: keep-alive
vary: Accept-Encoding

{"error":{"code":"not_found","message":"credencial não encontrada"}}
```

A `action` `test` é a de leitura: ela não grava nem apaga nada — o passo 1 do
handler resolve `secret_ref` com o JWT do requisitante e a RLS de
`ai_user_credentials` filtra sozinha; sem linha visível para B, o passo 2
(abrir o cliente de serviço) nunca chega a rodar.

## 3. Pelo PostgREST direto — 200 com corpo vazio

Com o JWT do próprio B, pedindo a linha de A por `id`:

```
$ curl -sS -i 'http://127.0.0.1:54321/rest/v1/ai_user_credentials?id=eq.f49bae71-7eee-4da9-9d81-342c582ee71d' \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $JWT_B"
```

saída real:

```
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Content-Length: 2
Connection: keep-alive
Content-Range: */*
Content-Location: /ai_user_credentials?id=eq.f49bae71-7eee-4da9-9d81-342c582ee71d

[]
```

`200` com `[]`, nunca a linha de A.

## 4. No banco, com a claim de B — RLS filtra, `auth.uid()` não é `NULL`

Tudo dentro de uma transação `begin`/`rollback`, que não muda estado:

```
$ docker compose -f infra/local/docker-compose.yml exec -T db psql -U supabase_admin -d postgres -f rls_check.sql
```

onde `rls_check.sql` é:

```sql
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"089cdc7a-96fa-46d9-b730-aef0d0cb0cb5","role":"authenticated"}';
select auth.uid();
select count(*) from public.ai_user_credentials;
rollback;
```

saída real:

```
BEGIN
SET
SET
                 uid
--------------------------------------
 089cdc7a-96fa-46d9-b730-aef0d0cb0cb5
(1 row)

 count
-------
     0
(1 row)

ROLLBACK
```

`select auth.uid()` devolve o uuid de B, não `NULL` — a claim está sendo lida
de verdade, então a contagem zero abaixo prova RLS filtrando o dono errado, e
não uma sessão ausente que zeraria a contagem pelo motivo trocado. A linha de
A (`f49bae71-7eee-4da9-9d81-342c582ee71d`) continua existindo — só não é
visível daqui, com a claim de B.

## Estado ao final

Nada foi deixado sujo pela prova em si: o passo 4 rodou dentro de
`begin`/`rollback`, e a `action test` do passo 2 é só leitura. A credencial
`f49bae71-7eee-4da9-9d81-342c582ee71d` de A e o usuário B
(`089cdc7a-96fa-46d9-b730-aef0d0cb0cb5`) permanecem na stack local — são dado
de teste local, descartado por `scripts/local-supabase.sh reset`.
