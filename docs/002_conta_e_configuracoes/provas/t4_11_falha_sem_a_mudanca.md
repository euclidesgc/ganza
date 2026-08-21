# T4.11 — prova de que o teste falha sem a mudança

Data: 2026-08-21. Alvo: `app/lib/app_router.dart`. Duas reversões
independentes, cada uma aplicada, executada e desfeita em seguida — a árvore
ficou como estava antes desta prova, confirmado por `git diff` limpo no
arquivo ao final de cada reversão.

## Reversão 1 — tirar do `redirect` o desvio dos caminhos que exigem IA

Derruba a primeira transição (ir a `/chat` sem IA configurada deveria
terminar em `/configuracoes/ia`, e não termina mais) e a terceira (apagar a
credencial deveria voltar a desviar, e não desvia mais), porque sem este
bloco o `redirect` nunca mais barra `/chat`.

```diff
--- a/app/lib/app_router.dart
+++ b/app/lib/app_router.dart
@@ -61,10 +61,6 @@ GoRouter createRouter({String initialLocation = AreasRoutes.path}) {
       }
       final aiConfigured = capabilities.state.capabilities.aiConfigured;
-      if (_aiGatedPaths.contains(location) && !aiConfigured) {
-        pendingAiGatedDestination = location;
-        return SettingsRoutes.aiFullPath;
-      }
       // O redirect só derruba o usuário para a tela de IA; a volta ao
```

### Comando

```
cd app && flutter test -r compact test/app_router_gate_test.dart
```

### Saída (vermelha, com a reversão acima aplicada)

```
00:02 +0: o gate de /chat barra sem IA configurada, libera ao configurar e volta a barrar ao apagar a credencial -- as três transições, mesma instância
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TypeWidgetFinder:<Found 0 widgets with type "SettingsAiPage": []>
   Which: means none were found but one was expected

This was caught by the test expectation on the following line:
  file:///app/test/app_router_gate_test.dart line 88
00:03 +0 -1: o gate de /chat barra sem IA configurada, libera ao configurar e volta a barrar ao apagar a credencial -- as três transições, mesma instância [E]
  Test failed. See exception logs above.
00:03 +0 -1: Some tests failed.
```

A primeira asserção (`find.byType(SettingsAiPage)` logo após tentar `/chat`
sem IA configurada) já falha — o caminho segue liberado, o que também
significa que a terceira transição (re-barrar ao apagar a credencial) não
tem mais bloco de redirect para executá-la.

### Restauração

Diff revertido logo em seguida — `git diff app/lib/app_router.dart` não
mostra nenhuma alteração pendente, e a suíte volta a passar.

## Reversão 2 — tirar o notificador de capacidades do `refreshListenable`

Derruba a segunda transição (a capacidade passando a configurada deveria
mostrar `ChatPage` no mesmo caminho, sem navegação manual) e a terceira
(apagar a credencial deveria re-barrar), porque o `go_router` só reavalia o
`redirect` numa navegação explícita ou quando o `refreshListenable`
notifica — e as duas dependem de o `redirect` ser reavaliado por emissão do
cubit, não por navegação.

```diff
--- a/app/lib/app_router.dart
+++ b/app/lib/app_router.dart
@@ -30,7 +30,6 @@ GoRouter createRouter({String initialLocation = AreasRoutes.path}) {
     refreshListenable: Listenable.merge([
       _SessionListenable(sessions),
       recoveryScope,
-      _CapabilitiesListenable(capabilities),
     ]),
```

### Comando

```
cd app && flutter test -r compact test/app_router_gate_test.dart
```

### Saída (vermelha, com a reversão acima aplicada)

```
00:02 +0: o gate de /chat barra sem IA configurada, libera ao configurar e volta a barrar ao apagar a credencial -- as três transições, mesma instância
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TypeWidgetFinder:<Found 0 widgets with type "ChatPage": []>
   Which: means none were found but one was expected

This was caught by the test expectation on the following line:
  file:///app/test/app_router_gate_test.dart line 101
00:04 +0 -1: o gate de /chat barra sem IA configurada, libera ao configurar e volta a barrar ao apagar a credencial -- as três transições, mesma instância [E]
  Test failed. See exception logs above.
00:04 +0 -1: Some tests failed.
```

A primeira transição ainda passa (o `redirect` continua barrando `/chat` na
navegação inicial, que não depende do `refreshListenable`). A segunda falha:
mesmo com `source.aiConfigured = true` e `capabilities.refresh()` já
concluído, sem o notificador no `refreshListenable` o `go_router` nunca
reavalia o caminho corrente e `ChatPage` não aparece — o que também barra a
terceira transição, que nunca é alcançada.

### Restauração

Diff revertido logo em seguida — `git diff app/lib/app_router.dart` não
mostra nenhuma alteração pendente, e a suíte volta a passar:

```
cd app && flutter test -r compact test/app_router_gate_test.dart
...
00:04 +1: All tests passed!
```

Duas execuções — uma por reversão —, não duas asserções dentro do mesmo
teste.
