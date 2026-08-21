# T4.10 — prova de que os testes falham sem a mudança

Três reversões pontuais, aplicadas uma de cada vez sobre
`app/lib/modules/settings_module/presentation/ai/widgets/ai_settings_form.dart`,
rodadas com `cd app && flutter test -r compact test/modules/settings_module/presentation/ai/ai_settings_page_test.dart`,
e desfeitas logo em seguida por edição reversa (nunca `git stash`) — a árvore
volta ao estado com a mudança antes da reversão seguinte. Execução em
2026-08-21.

## Reversão 1 — exibir a chave inteira

O sucesso do salvamento deixa de limpar o campo da chave: a linha que
condicionava a limpeza ao evento de sucesso vira `false` incondicional, então
o `TextEditingController` da `SecretField` continua com o valor inteiro
digitado depois de a credencial já constar como configurada.

```diff
--- app/lib/modules/settings_module/presentation/ai/widgets/ai_settings_form.dart (com a mudança)
+++ app/lib/modules/settings_module/presentation/ai/widgets/ai_settings_form.dart (revertido)
@@ -71,8 +71,7 @@
   @override
   Widget build(BuildContext context) {
     return BlocListener<AiSettingsCubit, AiSettingsState>(
-      listenWhen: (previous, current) =>
-          previous is AiSettingsSaving && current is AiSettingsReady,
+      listenWhen: (previous, current) => false,
       listener: _clearAfterSuccess,
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
```

Saída vermelha:

```
00:05 +0: com credencial existente mostra provedor, modelo, os quatro últimos dígitos e a marca de configurada, sem expor a chave inteira

══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: no matching candidates
  Actual: _TextWidgetFinder:<Found 1 widget with text "sk-ganza-test-4242": [
            EditableText-[LabeledGlobalKey<EditableTextState>#06182](controller:
TextEditingController#055ff(TextEditingValue(text: ┤sk-ganza-test-4242├, selection:
TextSelection.collapsed(offset: 18, ...), obscureText: true, ...)),
          ]>
   Which: means one was found but none were expected

This was caught by the test expectation on the following line:
  file:///.../app/test/modules/settings_module/presentation/ai/ai_settings_page_test.dart:97

00:05 +0 -1: com credencial existente mostra provedor, modelo, os quatro últimos dígitos e a marca de configurada, sem expor a chave inteira [E]
  Test failed. See exception logs above.
00:05 +2 -1: Some tests failed.
```

Árvore restaurada em seguida com o conteúdo original do arquivo (confirmado
por `diff` sem saída), e a suíte voltou a passar.

## Reversão 2 — habilitar o salvar com o campo vazio

O getter que decide se o formulário pode ser enviado passa a devolver `true`
sempre, ignorando se provedor, modelo e chave estão preenchidos.

```diff
--- app/lib/modules/settings_module/presentation/ai/widgets/ai_settings_form.dart (com a mudança)
+++ app/lib/modules/settings_module/presentation/ai/widgets/ai_settings_form.dart (revertido)
@@ -37,10 +37,7 @@
     super.dispose();
   }

-  bool get _canSubmit =>
-      _providerKindId != null &&
-      _modelController.text.trim().isNotEmpty &&
-      _apiKeyController.text.trim().isNotEmpty;
+  bool get _canSubmit => true;

   void _onFieldsChanged(String _) => setState(() {});
```

Saída vermelha:

```
00:05 +1: o campo da chave é o SecretField e o botão de salvar fica desabilitado com o campo vazio e enquanto o envio está em voo

══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: null
  Actual: <Closure: () => void from Function '_save@194256878':.>

This was caught by the test expectation on the following line:
  file:///.../app/test/modules/settings_module/presentation/ai/ai_settings_page_test.dart:124

00:05 +1 -1: o campo da chave é o SecretField e o botão de salvar fica desabilitado com o campo vazio e enquanto o envio está em voo [E]
  Test failed. See exception logs above.
00:05 +2 -1: Some tests failed.
```

O `onPressed` do botão de salvar (chave `ai-settings-save-button`), medido
antes de qualquer campo ser preenchido, deixou de ser `null` — o botão ficou
clicável com o formulário vazio. Árvore restaurada em seguida, suíte verde de
novo.

## Reversão 3 — limpar o campo no erro

O gatilho de limpeza passa a disparar em qualquer transição que saía de
`AiSettingsSaving`, sucesso ou falha, e o próprio corpo do método de limpeza
deixa de checar se o novo estado é `AiSettingsReady` — a chave digitada some
do formulário mesmo quando o servidor recusa o salvamento.

```diff
--- app/lib/modules/settings_module/presentation/ai/widgets/ai_settings_form.dart (com a mudança)
+++ app/lib/modules/settings_module/presentation/ai/widgets/ai_settings_form.dart (revertido)
@@ -62,7 +62,6 @@
   // continuar viva num TextEditingController depois de já ter sido enviada.
   // O erro, ao contrário, preserva: é o servidor que falhou, não o usuário.
   void _clearAfterSuccess(BuildContext context, AiSettingsState state) {
-    if (state is! AiSettingsReady) return;
     _modelController.clear();
     _apiKeyController.clear();
     setState(() => _providerKindId = null);
@@ -71,8 +70,7 @@
   @override
   Widget build(BuildContext context) {
     return BlocListener<AiSettingsCubit, AiSettingsState>(
-      listenWhen: (previous, current) =>
-          previous is AiSettingsSaving && current is AiSettingsReady,
+      listenWhen: (previous, current) => previous is AiSettingsSaving,
       listener: _clearAfterSuccess,
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
```

Saída vermelha:

```
00:05 +2: um erro de servidor preserva o que foi digitado

══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "gemini-2.0-flash": []>
   Which: means none were found but one was expected

This was caught by the test expectation on the following line:
  file:///.../app/test/modules/settings_module/presentation/ai/ai_settings_page_test.dart:173

00:05 +2 -1: um erro de servidor preserva o que foi digitado [E]
  Test failed. See exception logs above.
00:05 +2 -1: Some tests failed.
```

Árvore restaurada em seguida, confirmada por `diff` sem saída contra o
arquivo com a mudança, e a suíte completa do módulo voltou a passar (20
testes, `All tests passed!`).
