# T5.5 — prova de "falha sem a mudança"

Data: 2026-08-21. Árvore restaurada logo após capturar cada saída vermelha
(confirmado por `diff` contra a versão boa antes de seguir).

## Diff 1 — `capabilities_source_impl.dart` volta a fixar `bankConnected` em `false`

```diff
--- a/app/lib/modules/settings_module/data/repositories/capabilities_source_impl.dart
+++ b/app/lib/modules/settings_module/data/repositories/capabilities_source_impl.dart
@@ -6,9 +6,6 @@ import '../../../../core/network/failure_from_exception.dart';
 import '../../../../core/session/capabilities_source.dart';
 import '../../../../core/session/user_capabilities.dart';
 
-/// Banco conectado fica fixo em `false`: a integração bancária é a Fase 5 e
-/// hoje não existe fonte nenhuma para essa capacidade. Um `false` honesto
-/// vale mais que um campo que finge saber.
 class CapabilitiesSourceImpl implements CapabilitiesSource {
   const CapabilitiesSourceImpl(this._client);
 
@@ -17,14 +14,23 @@ class CapabilitiesSourceImpl implements CapabilitiesSource {
   @override
   Future<Either<Failure, UserCapabilities>> load() async {
     try {
-      final rows = await _client
+      final aiRows = await _client
           .from('ai_user_credentials')
           .select('id')
           .eq('is_active', true)
           .limit(1);
 
+      final bankRows = await _client
+          .from('bank_connections')
+          .select('id')
+          .neq('status', 'disconnected')
+          .limit(1);
+
       return Right(
-        UserCapabilities(aiConfigured: rows.isNotEmpty, bankConnected: false),
+        UserCapabilities(
+          aiConfigured: aiRows.isNotEmpty,
+          bankConnected: bankRows.isNotEmpty,
+        ),
       );
     } catch (error) {
       return Left(failureFromException(error));
```

Comando: `cd app && flutter test -r compact test/modules/settings_module/data/repositories/capabilities_source_impl_test.dart`

Saída vermelha (com o diff acima revertido, ou seja, com `bankConnected: false` fixo):

```
CapabilitiesSourceImpl.load conexão bancária ativa devolve bankConnected true [E]
  Expected: Right<Failure, UserCapabilities>:<Right(UserCapabilities(false, true))>
    Actual: Right<Failure, UserCapabilities>:<Right(UserCapabilities(false, false))>
```

## Diff 2 — `bank_connection_model.dart` cai num padrão silencioso para `status` desconhecido

```diff
--- a/app/lib/modules/settings_module/data/models/bank_connection_model.dart
+++ b/app/lib/modules/settings_module/data/models/bank_connection_model.dart
@@ -29,7 +29,7 @@
   static final _schema = z.map({
     'id': z.string(),
     'institution_name': z.string(),
-    'status': z.$enum(['pending', 'connected', 'error', 'disconnected']),
+    'status': z.string(),
     'last_synced_at': _NullableString(z.string()),
   });
 
@@ -59,10 +59,10 @@
       BankConnection(
         id: data['id'] as String,
         institution: data['institution_name'] as String,
-        // O `z.$enum` acima já restringe `status` aos quatro valores da
-        // check constraint de `bank_connections` — chegando aqui, o valor é
-        // sempre um nome válido de `BankConnectionStatus`.
-        status: BankConnectionStatus.values.byName(data['status'] as String),
+        status: BankConnectionStatus.values.firstWhere(
+          (status) => status.name == data['status'],
+          orElse: () => BankConnectionStatus.pending,
+        ),
         lastSyncedAt: lastSyncedAt?.toUtc(),
       ),
     );
```

Comando: `cd app && flutter test -r compact test/modules/settings_module/data/models/bank_connection_model_test.dart`

Saída vermelha (com o diff acima aplicado, ou seja, `status` sem validação de enum e com `orElse` para `pending`):

```
BankConnectionModel.fromMap status fora dos quatro valores do enum vira ValidationFailure [E]
  Expected: <Instance of 'ValidationFailure'>
    Actual: <null>
     Which: is not an instance of 'ValidationFailure'
```

Ambos os diffs foram desfeitos por edição reversa (nunca `git stash`) logo após a captura, e a árvore foi conferida por `diff` contra a versão íntegra antes de seguir.
