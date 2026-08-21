# T5.3 — prova de que o teste falha sem a mudança

Data: 2026-08-21. Alvo: `supabase/functions/bank-connections/handler.ts`,
`handleDisconnect`, removendo por um instante o corte de dono (o `if
(connection === null) return 404` sai, e a rota passa a tratar `connection ===
null` como "usa o próprio `connection_id` como `item_id`") e revertendo em
seguida — a árvore ficou como estava antes desta prova.

## Diff aplicado (e desfeito) no handler

```diff
--- a/supabase/functions/bank-connections/handler.ts
+++ b/supabase/functions/bank-connections/handler.ts
@@ -249,17 +249,14 @@ async function handleDisconnect(
   }

   const connection = await findOwnConnection(supabase, connectionId);
-  if (connection === null) {
-    return errorResponse('not_found', 'conexão não encontrada', 404);
-  }
-
-  const itemId = connectionItemId(connection);
+
+  const itemId = connection === null ? connectionId : connectionItemId(connection);
   if (itemId === null) {
     console.error('bank_connections sem item_id', { connection_id: connectionId });
     return errorResponse('internal_error', 'conexão sem item associado', 500);
   }

   const apiKey = await pluggyAuthenticate(pluggyClientId, pluggyClientSecret);
   await pluggyFetch(`/items/${itemId}`, apiKey, { method: 'DELETE' });
```

## Comando

```
cd supabase/functions && deno test --allow-env --allow-net bank-connections/handler_test.ts --filter "404"
```

## Saída (vermelha, com a inversão acima aplicada)

```
running 1 test from ./bank-connections/handler_test.ts
404: desconectar um identificador de conexão de outro usuário ...
------- output -------
pluggy indisponível { action: "disconnect" }
----- output end -----
404: desconectar um identificador de conexão de outro usuário ... FAILED (21ms)

 ERRORS

404: desconectar um identificador de conexão de outro usuário => ./bank-connections/handler_test.ts:199:6
error: AssertionError: Values are not equal.

    [Diff] Actual / Expected


-   502
+   404

  throw new AssertionError(message);
        ^
    at assertEquals (https://jsr.io/@std/assert/1.0.19/equals.ts:67:9)
    at file:///.../supabase/functions/bank-connections/handler_test.ts:217:3

 FAILURES

404: desconectar um identificador de conexão de outro usuário => ./bank-connections/handler_test.ts:199:6

FAILED | 0 passed | 1 failed | 12 filtered out (26ms)

error: Test failed
```

Sem o corte de dono, o handler tenta autenticar e apagar o item na Pluggy
mesmo para uma conexão que não existe para este usuário; o teste stuba a
Pluggy como fora do ar nesse cenário, e por isso o código cai no branch de
`pluggy_unavailable` (502) em vez do `not_found` (404) esperado — a asserção
`assertEquals(resposta.status, 404)` falha exatamente como acima.

## Restauração

O diff acima foi revertido logo em seguida — o handler voltou a checar
`connection === null` antes de tocar a Pluggy, e a suíte completa volta a
passar:

```
cd supabase/functions && deno test --allow-env --allow-net bank-connections/handler_test.ts --filter "404"
running 1 test from ./bank-connections/handler_test.ts
404: desconectar um identificador de conexão de outro usuário ... ok (18ms)

ok | 1 passed | 0 failed | 12 filtered out (23ms)
```
