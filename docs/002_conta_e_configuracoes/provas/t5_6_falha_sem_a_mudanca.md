# T5.6 — provas de "falha sem a mudança"

Três reversões pontuais, cada uma aplicada, testada em vermelho e desfeita em
seguida. Comando usado nas três: `cd app && flutter test -r compact <arquivo>`.
Data: 21/08/2026. Árvore restaurada ao final de cada uma — conferido com
`git diff --no-color -- <arquivo>` vazio depois de cada reversão desfeita.

## 1. Rótulo textual trocado por distinção só de cor

Arquivo: `app/lib/modules/settings_module/presentation/bank/widgets/bank_connection_status_card.dart`.
Os quatro `label` do `switch` viram o mesmo texto ("Status da conexão"),
sobrando só a cor para diferenciar os estados.

```diff
diff --git a/app/lib/modules/settings_module/presentation/bank/widgets/bank_connection_status_card.dart b/app/lib/modules/settings_module/presentation/bank/widgets/bank_connection_status_card.dart
index 83a94ea..e85cc87 100644
--- a/app/lib/modules/settings_module/presentation/bank/widgets/bank_connection_status_card.dart
+++ b/app/lib/modules/settings_module/presentation/bank/widgets/bank_connection_status_card.dart
@@ -20,25 +20,25 @@ class BankConnectionStatusCard extends StatelessWidget {
   Widget build(BuildContext context) {
     final (label, icon, foreground, background) = switch (status) {
       BankConnectionStatus.connected => (
-        'Banco conectado',
+        'Status da conexão',
         AppIcons.connectedStatus,
         context.ganza.done,
         context.ganza.doneSoft,
       ),
       BankConnectionStatus.pending => (
-        'Conexão pendente',
+        'Status da conexão',
         AppIcons.bank,
         context.ganza.forecast,
         context.ganza.elevatedSurface,
       ),
       BankConnectionStatus.error => (
-        'Erro na conexão',
+        'Status da conexão',
         AppIcons.errorState,
         context.ganza.overdue,
         context.ganza.overdueSoft,
       ),
       BankConnectionStatus.disconnected => (
-        'Banco desconectado',
+        'Status da conexão',
         AppIcons.notConfiguredStatus,
         context.ganza.mutedInk,
         context.ganza.elevatedSurface,
```

Saída vermelha de `cd app && flutter test -r compact test/modules/settings_module/presentation/bank/bank_settings_page_test.dart`
— os quatro casos do grupo "os quatro estados de conexão renderizam rótulo
textual distinto" falham, um por um:

```
00:08 +0 -1: os quatro estados de conexão renderizam rótulo textual distinto pendente mostra "Conexão pendente" [E]
  Test failed. See exception logs above.
00:08 +0 -2: os quatro estados de conexão renderizam rótulo textual distinto conectado mostra "Banco conectado" [E]
  Test failed. See exception logs above.
00:08 +0 -3: os quatro estados de conexão renderizam rótulo textual distinto erro mostra "Erro na conexão" [E]
  Test failed. See exception logs above.
00:09 +0 -4: os quatro estados de conexão renderizam rótulo textual distinto desconectado mostra "Banco desconectado" [E]
  Test failed. See exception logs above.
...
00:10 +1 -6: Some tests failed.
```

Reversão desfeita (os quatro `label` voltaram ao texto próprio de cada
estado); `git diff --no-color -- app/lib/modules/settings_module/presentation/bank/widgets/bank_connection_status_card.dart`
vazio depois, e a suíte volta a `+7`.

## 2. Desconectar agindo sem confirmação

Arquivo: `app/lib/modules/settings_module/presentation/bank/widgets/bank_disconnect_button.dart`.
`_confirmAndDisconnect` deixa de abrir o `BankDisconnectConfirmDialog` e chama
`cubit.disconnect()` direto no toque.

```diff
diff --git a/app/lib/modules/settings_module/presentation/bank/widgets/bank_disconnect_button.dart b/app/lib/modules/settings_module/presentation/bank/widgets/bank_disconnect_button.dart
index 1d811f4..1216608 100644
--- a/app/lib/modules/settings_module/presentation/bank/widgets/bank_disconnect_button.dart
+++ b/app/lib/modules/settings_module/presentation/bank/widgets/bank_disconnect_button.dart
@@ -12,11 +12,6 @@ class BankDisconnectButton extends StatelessWidget {
 
   Future<void> _confirmAndDisconnect(BuildContext context) async {
     final cubit = context.read<BankSettingsCubit>();
-    final confirmed = await showDialog<bool>(
-      context: context,
-      builder: (_) => const BankDisconnectConfirmDialog(),
-    );
-    if (confirmed != true) return;
     await cubit.disconnect();
   }
```

Saída vermelha de `cd app && flutter test -r compact test/modules/settings_module/presentation/bank/bank_settings_page_test.dart`
— os dois casos do grupo "desconectar pede confirmação explícita" falham: o
de cancelar quebra porque `disconnect()` já foi chamado sem o dublê saber
responder (`type 'Null' is not a subtype of type 'Future<Either<Failure, Unit>>'`)
e o diálogo nunca aparece; o de confirmar quebra porque não há mais
`bank-disconnect-confirm-accept` para tocar:

```
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════
The following _TypeError was thrown running a test:
type 'Null' is not a subtype of type 'Future<Either<Failure, Unit>>'
...
00:11 +4 -1: desconectar pede confirmação explícita cancelar não chama a desconexão e mantém o estado conectado [E]
  Test failed. See exception logs above.

The finder "Found 0 widgets with key [<'bank-disconnect-confirm-accept'>]: []" (used in a call to
"tap()") could not find any matching widgets.
00:11 +4 -2: desconectar pede confirmação explícita confirmar chama a desconexão [E]
  Test failed. See exception logs above.
...
00:11 +5 -2: Some tests failed.
```

Reversão desfeita (a chamada a `showDialog` e o `if (confirmed != true) return;`
voltaram); `git diff --no-color -- app/lib/modules/settings_module/presentation/bank/widgets/bank_disconnect_button.dart`
vazio depois, e a suíte volta a `+7`.

## 3. Entrada de Banco removida da home de Configurações

Arquivo: `app/lib/modules/settings_module/presentation/settings_home/widgets/settings_section_list.dart`.
O `SettingsSectionTile` de "Banco" sai da lista.

```diff
diff --git a/app/lib/modules/settings_module/presentation/settings_home/widgets/settings_section_list.dart b/app/lib/modules/settings_module/presentation/settings_home/widgets/settings_section_list.dart
index 7c6fba1..05386f3 100644
--- a/app/lib/modules/settings_module/presentation/settings_home/widgets/settings_section_list.dart
+++ b/app/lib/modules/settings_module/presentation/settings_home/widgets/settings_section_list.dart
@@ -22,11 +22,6 @@ class SettingsSectionList extends StatelessWidget {
           label: 'IA',
           onTap: () => context.pushNamed(SettingsRoutes.aiName),
         ),
-        const SizedBox(height: AppSpacing.sm),
-        SettingsSectionTile(
-          label: 'Banco',
-          onTap: () => context.pushNamed(SettingsRoutes.bankName),
-        ),
       ],
     );
   }
```

Saída vermelha de `cd app && flutter test -r compact test/app_router_test.dart`
— o teste de cadeia "a partir da tela inicial, drawer > Configurações > Banco
chega a /configuracoes/banco sem o placeholder" não encontra mais o item para
tocar:

```
The following assertion was thrown running a test:
The finder "Found 0 widgets with text "Banco": []" (used in a call to "tap()") could not find any
matching widgets.
...
00:15 +4 -1: a partir da tela inicial, drawer > Configurações > Banco chega a /configuracoes/banco sem o placeholder [E]
  Test failed. See exception logs above.
00:15 +4 -1: Some tests failed.
```

Reversão desfeita (o `SizedBox` e o `SettingsSectionTile` de "Banco"
voltaram); `git diff --no-color -- app/lib/modules/settings_module/presentation/settings_home/widgets/settings_section_list.dart`
vazio depois, e `test/app_router_test.dart` volta a `+5`.
