# T4.5 — prova de que `main/env_test.ts` falha sem a mudança

Data: 2026-08-21. Execução: `cd supabase/functions && deno test --allow-env --allow-net main/env_test.ts`, com `main/env.ts` temporariamente reescrito para voltar a devolver `SUPABASE_SERVICE_ROLE_KEY` na lista comum, igual ao `envVars` literal que o `index.ts` montava antes desta tarefa. Depois da captura, o arquivo foi restaurado ao estado correto (idêntico ao commit desta tarefa) e a suíte voltou a passar — ver a segunda seção.

## Diff que devolve a chave à lista comum

```diff
--- a/supabase/functions/main/env.ts
+++ b/supabase/functions/main/env.ts
@@ -6,19 +6,12 @@
   SUPABASE_JWT_SECRET?: string;
 }

-const FUNCOES_COM_SERVICE_ROLE = new Set(['ai-credentials']);
-
-export function envVarsFor(nome: string, fonte: EnvFonte): [string, string][] {
-  const vars: [string, string][] = [
+export function envVarsFor(_nome: string, fonte: EnvFonte): [string, string][] {
+  return [
     ['SUPABASE_URL', fonte.SUPABASE_URL ?? ''],
     ['SUPABASE_ANON_KEY', fonte.SUPABASE_ANON_KEY ?? ''],
+    ['SUPABASE_SERVICE_ROLE_KEY', fonte.SUPABASE_SERVICE_ROLE_KEY ?? ''],
     ['SUPABASE_DB_URL', fonte.SUPABASE_DB_URL ?? ''],
     ['SUPABASE_JWT_SECRET', fonte.SUPABASE_JWT_SECRET ?? ''],
   ];
-
-  if (FUNCOES_COM_SERVICE_ROLE.has(nome)) {
-    vars.push(['SUPABASE_SERVICE_ROLE_KEY', fonte.SUPABASE_SERVICE_ROLE_KEY ?? '']);
-  }
-
-  return vars;
 }
```

## Saída vermelha com esse diff aplicado

```
running 3 tests from ./main/env_test.ts
transactions não recebe SUPABASE_SERVICE_ROLE_KEY ... FAILED (5ms)
health não recebe SUPABASE_SERVICE_ROLE_KEY ... FAILED (1ms)
ai-credentials recebe SUPABASE_SERVICE_ROLE_KEY ... ok (0ms)

 ERRORS

transactions não recebe SUPABASE_SERVICE_ROLE_KEY => ./main/env_test.ts:16:6
error: AssertionError: Values are not equal.

    [Diff] Actual / Expected


-   true
+   false

health não recebe SUPABASE_SERVICE_ROLE_KEY => ./main/env_test.ts:20:6
error: AssertionError: Values are not equal.

    [Diff] Actual / Expected


-   true
+   false

 FAILURES

transactions não recebe SUPABASE_SERVICE_ROLE_KEY => ./main/env_test.ts:16:6
health não recebe SUPABASE_SERVICE_ROLE_KEY => ./main/env_test.ts:20:6

FAILED | 1 passed | 2 failed (10ms)
error: Test failed
```

## Árvore restaurada

Depois da captura, `supabase/functions/main/env.ts` foi restaurado ao conteúdo do commit desta tarefa (o `diff` acima revertido) e a suíte confirmada verde de novo:

```
running 3 tests from ./main/env_test.ts
transactions não recebe SUPABASE_SERVICE_ROLE_KEY ... ok (1ms)
health não recebe SUPABASE_SERVICE_ROLE_KEY ... ok (0ms)
ai-credentials recebe SUPABASE_SERVICE_ROLE_KEY ... ok (0ms)

ok | 3 passed | 0 failed (4ms)
```
