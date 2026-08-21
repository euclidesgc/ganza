# T4.4 — prova de que `ai-credentials/handler_test.ts` falha sem a mudança

Data: 2026-08-21. Execução: `cd supabase/functions && deno test --allow-env --allow-net ai-credentials/handler_test.ts`, com `ai-credentials/handler.ts` temporariamente mutado em dois defeitos separados, um de cada vez. Depois de cada captura, o arquivo foi restaurado ao estado correto (idêntico ao commit desta tarefa) por edição reversa pontual — nunca `git stash` — e a suíte confirmada verde de novo.

## Defeito 1 — inverte a ordem dos dois passos em `handleTest`

Chama a `service_role` primeiro, com o `credential_id` do corpo direto como `secret_ref`, e só depois faz a consulta de posse filtrada pelo JWT. É exatamente a vulnerabilidade que o desenho de dois passos existe para impedir: a decifra deixa de depender de qualquer verificação de dono.

```diff
--- a/supabase/functions/ai-credentials/handler.ts
+++ b/supabase/functions/ai-credentials/handler.ts
@@ -128,32 +128,26 @@
-  // Passo 1: resolve o secret_ref com o JWT do requisitante — a RLS de
-  // ai_user_credentials filtra por dono sozinha. Passo 2, abaixo, só abre a
-  // service_role depois disso, e só para o uuid que este passo devolveu.
-  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
-    global: { headers: { Authorization: authorization } },
-    auth: { persistSession: false, autoRefreshToken: false },
-  });
-
-  const { data, error } = await userClient
-    .from('ai_user_credentials')
-    .select('secret_ref')
-    .eq('id', credentialId)
-    .maybeSingle();
-
-  if (error) {
-    console.error('ai_user_credentials select falhou', { code: error.code });
-    return errorResponse('internal_error', 'não foi possível localizar a credencial', 500);
-  }
-
-  if (!data || typeof data.secret_ref !== 'string') {
-    return errorResponse('not_found', 'credencial não encontrada', 404);
-  }
-
-  const secretRef = data.secret_ref;
-
-  const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
-    auth: { persistSession: false, autoRefreshToken: false },
-  });
-
-  // Só decifra para provar que o Vault entrega a chave de volta; chamar o
-  // provedor de verdade é da camada de IA da Fase 6 (ai_providers/execute()).
-  const { error: revealError } = await serviceClient.rpc('ai_credential_reveal', {
-    secret_ref: secretRef,
-  });
-
-  if (revealError) {
+  const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
+    auth: { persistSession: false, autoRefreshToken: false },
+  });
+
+  const { error: revealError } = await serviceClient.rpc('ai_credential_reveal', {
+    secret_ref: credentialId,
+  });
+
+  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
+    global: { headers: { Authorization: authorization } },
+    auth: { persistSession: false, autoRefreshToken: false },
+  });
+
+  const { data, error } = await userClient
+    .from('ai_user_credentials')
+    .select('secret_ref')
+    .eq('id', credentialId)
+    .maybeSingle();
+
+  if (error) {
+    console.error('ai_user_credentials select falhou', { code: error.code });
+    return errorResponse('internal_error', 'não foi possível localizar a credencial', 500);
+  }
+
+  if (!data || typeof data.secret_ref !== 'string') {
+    return errorResponse('not_found', 'credencial não encontrada', 404);
+  }
+
+  if (revealError) {
     console.error('ai_credential_reveal falhou', { code: revealError.code });
     return errorResponse('provider_key_invalid', 'não foi possível validar a chave', 502);
   }
```

### Saída vermelha com esse diff aplicado

```
running 8 tests from ./ai-credentials/handler_test.ts
save: user_id do corpo é ignorado, o dono vem do JWT via GoTrue ... ok (10ms)
save: model numérico é rejeitado antes de qualquer chamada de rede ... ok (0ms)
test: secret_ref e user_id do corpo são ignorados; a decifra só usa o que o passo 1 devolveu ... FAILED (6ms)
test: credencial de outro usuário devolve 404 e nunca chega na service_role ... FAILED (2ms)
401: sem Authorization não chega a olhar corpo nem banco ... ok (0ms)
save: nem a chave em claro nem a resposta vazam — resposta traz só modelo, last4 e provedor ... ok (1ms)
test: nem o secret_ref real vaza na resposta nem no log ... ok (1ms)
delete: some do dono passa pela RLS e apaga sem tocar a service_role ... ok (1ms)

 ERRORS

test: secret_ref e user_id do corpo são ignorados; a decifra só usa o que o passo 1 devolveu => ./ai-credentials/handler_test.ts:175:6
error: AssertionError: Values are not equal.

    [Diff] Actual / Expected


-   false
+   true

test: credencial de outro usuário devolve 404 e nunca chega na service_role => ./ai-credentials/handler_test.ts:218:6
error: AssertionError: Values are not equal.

    [Diff] Actual / Expected


-   true
+   false

 FAILURES

test: secret_ref e user_id do corpo são ignorados; a decifra só usa o que o passo 1 devolveu => ./ai-credentials/handler_test.ts:175:6
test: credencial de outro usuário devolve 404 e nunca chega na service_role => ./ai-credentials/handler_test.ts:218:6

FAILED | 6 passed | 2 failed (29ms)
error: Test failed
```

Inverter os dois passos quebra as duas asserções ao mesmo tempo: o menor índice com o header da `service_role` deixa de ser maior que `0` (agora é `0`), e a credencial de outro usuário passa a gerar uma chamada com a chave de serviço antes do 404 — exatamente o vazamento entre usuários que a Fase 4 existe para impedir.

## Defeito 2 — `console.error` com a chave em claro em `handleSave`

```diff
--- a/supabase/functions/ai-credentials/handler.ts
+++ b/supabase/functions/ai-credentials/handler.ts
@@ -100,6 +100,8 @@
+  console.error('ai_credential_save concluído', { apiKey });
+
   return Response.json(
     { id: data, provider_kind_id: providerKindId, model, key_last4: apiKey.slice(-4) },
     { status: 201 },
   );
```

### Saída vermelha com esse diff aplicado

```
running 8 tests from ./ai-credentials/handler_test.ts
save: user_id do corpo é ignorado, o dono vem do JWT via GoTrue ... ok (11ms)
save: model numérico é rejeitado antes de qualquer chamada de rede ... ok (0ms)
test: secret_ref e user_id do corpo são ignorados; a decifra só usa o que o passo 1 devolveu ... ok (5ms)
test: credencial de outro usuário devolve 404 e nunca chega na service_role ... ok (1ms)
401: sem Authorization não chega a olhar corpo nem banco ... ok (0ms)
save: nem a chave em claro nem a resposta vazam — resposta traz só modelo, last4 e provedor ... FAILED (3ms)
test: nem o secret_ref real vaza na resposta nem no log ... ok (2ms)
delete: some do dono passa pela RLS e apaga sem tocar a service_role ... ok (1ms)

 ERRORS

save: nem a chave em claro nem a resposta vazam — resposta traz só modelo, last4 e provedor => ./ai-credentials/handler_test.ts:249:6
error: AssertionError: Values are not equal.

    [Diff] Actual / Expected


-   true
+   false

 FAILURES

save: nem a chave em claro nem a resposta vazam — resposta traz só modelo, last4 e provedor => ./ai-credentials/handler_test.ts:249:6

FAILED | 7 passed | 1 failed (34ms)
error: Test failed
```

O stub de `console.*` capturou `placeholder-de-teste-t44-Z9K2` na entrada `ai_credential_save concluído { apiKey: "placeholder-de-teste-t44-Z9K2" }`, e a asserção que varre as mensagens capturadas em busca desse literal detectou o vazamento.

## Árvore restaurada

Depois de cada captura, `supabase/functions/ai-credentials/handler.ts` foi restaurado ao conteúdo do commit desta tarefa (os dois diffs acima revertidos, um de cada vez) e a suíte confirmada verde de novo:

```
running 8 tests from ./ai-credentials/handler_test.ts
save: user_id do corpo é ignorado, o dono vem do JWT via GoTrue ... ok (10ms)
save: model numérico é rejeitado antes de qualquer chamada de rede ... ok (0ms)
test: secret_ref e user_id do corpo são ignorados; a decifra só usa o que o passo 1 devolveu ... ok (4ms)
test: credencial de outro usuário devolve 404 e nunca chega na service_role ... ok (1ms)
401: sem Authorization não chega a olhar corpo nem banco ... ok (0ms)
save: nem a chave em claro nem a resposta vazam — resposta traz só modelo, last4 e provedor ... ok (1ms)
test: nem o secret_ref real vaza na resposta nem no log ... ok (1ms)
delete: some do dono passa pela RLS e apaga sem tocar a service_role ... ok (1ms)

ok | 8 passed | 0 failed (25ms)
```
