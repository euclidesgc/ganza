# T4.6 — prova de que o teste falha sem a mudança

Data: 2026-08-21. Alvo: `app/lib/core/session/capabilities_cubit.dart`, o
método `refresh()`, invertendo por um instante o padrão de falha fechada
(`Left` passa a resultar em `aiConfigured: true`) e revertendo em seguida —
a árvore ficou como estava antes desta prova.

## Diff aplicado (e desfeito) no cubit

```diff
--- a/app/lib/core/session/capabilities_cubit.dart
+++ b/app/lib/core/session/capabilities_cubit.dart
@@ -16,7 +16,9 @@ class CapabilitiesCubit extends Cubit<CapabilitiesState> {
     emit(
       result.fold(
-        (_) => const CapabilitiesLoaded(UserCapabilities.unresolved()),
+        (_) => const CapabilitiesLoaded(
+          UserCapabilities(aiConfigured: true, bankConnected: false),
+        ),
         CapabilitiesLoaded.new,
       ),
     );
```

## Comando

```
cd app && flutter test -r compact test/core/session/capabilities_cubit_test.dart
```

## Saída (vermelha, com a inversão acima aplicada)

```
00:02 +0: refresh fonte que devolve Left resulta em IA configurada false
00:02 +0 -1: refresh fonte que devolve Left resulta em IA configurada false [E]
  Expected: false
    Actual: <true>

  package:matcher                                      expect
  package:flutter_test/src/widget_tester.dart 473:18   expect
  test/core/session/capabilities_cubit_test.dart 27:7  main.<fn>.<fn>

To run this test again: dart test test/core/session/capabilities_cubit_test.dart -p vm --plain-name 'refresh fonte que devolve Left resulta em IA configurada false'
00:02 +0 -1: refresh fonte que devolve Right repassa as capacidades lidas
00:02 +1 -1: refresh fonte que devolve Right repassa as capacidades lidas
00:03 +1 -1: Some tests failed.
```

## Restauração

O diff acima foi revertido logo em seguida — `git diff app/lib/core/session/capabilities_cubit.dart`
não mostra nenhuma alteração pendente neste arquivo, e a suíte volta a passar:

```
cd app && flutter test -r compact test/core/session/capabilities_cubit_test.dart
...
00:02 +2: All tests passed!
```
