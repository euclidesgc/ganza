import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/core/widgets/forms/secret_field.dart';
import 'package:ganza/modules/settings_module/domain/domain.dart';
import 'package:ganza/modules/settings_module/presentation/ai/ai_settings_cubit.dart';
import 'package:ganza/modules/settings_module/presentation/ai/settings_ai_page.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetAiProviderKinds extends Mock implements GetAiProviderKinds {}

class _MockGetAiCredential extends Mock implements GetAiCredential {}

class _MockSaveAiCredential extends Mock implements SaveAiCredential {}

void main() {
  late _MockGetAiProviderKinds getProviderKinds;
  late _MockGetAiCredential getCredential;
  late _MockSaveAiCredential saveCredential;

  const providerKind = AiProviderKind(
    id: 'p1',
    slug: 'gemini',
    label: 'Google Gemini',
  );
  const modelDigitado = 'gemini-2.0-flash';
  const chaveDigitada = 'sk-ganza-test-4242';

  setUp(() {
    getProviderKinds = _MockGetAiProviderKinds();
    getCredential = _MockGetAiCredential();
    saveCredential = _MockSaveAiCredential();
    when(
      () => getProviderKinds(),
    ).thenAnswer((_) async => const Right([providerKind]));
    when(() => getCredential()).thenAnswer((_) async => const Right(null));
  });

  Widget montar() => MaterialApp(
    theme: AppTheme.light,
    home: BlocProvider<AiSettingsCubit>(
      create: (_) =>
          AiSettingsCubit(getProviderKinds, getCredential, saveCredential)
            ..load(),
      child: const SettingsAiPage(),
    ),
  );

  Future<void> preencherFormulario(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('ai-settings-provider-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google Gemini'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('ai-settings-model-field')),
      modelDigitado,
    );
    await tester.enterText(find.byType(SecretField), chaveDigitada);
    await tester.pump();
  }

  testWidgets(
    'com credencial existente mostra provedor, modelo, os quatro últimos '
    'dígitos e a marca de configurada, sem expor a chave inteira',
    (tester) async {
      when(
        () => saveCredential(
          providerKindId: any(named: 'providerKindId'),
          model: any(named: 'model'),
          apiKey: any(named: 'apiKey'),
        ),
      ).thenAnswer(
        (_) async => const Right(
          AiCredential(
            id: 'c1',
            providerKindId: 'p1',
            model: modelDigitado,
            keyLast4: '4242',
            isActive: true,
          ),
        ),
      );

      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      await preencherFormulario(tester);

      await tester.tap(find.byKey(const Key('ai-settings-save-button')));
      await tester.pumpAndSettle();

      expect(find.text(chaveDigitada), findsNothing);
      expect(find.textContaining('IA configurada'), findsOneWidget);
      expect(find.textContaining('Google Gemini'), findsOneWidget);
      expect(find.textContaining(modelDigitado), findsOneWidget);
      expect(find.textContaining('4242'), findsOneWidget);
    },
  );

  testWidgets(
    'o campo da chave é o SecretField e o botão de salvar fica desabilitado '
    'com o campo vazio e enquanto o envio está em voo',
    (tester) async {
      final completer = Completer<Either<Failure, AiCredential>>();
      when(
        () => saveCredential(
          providerKindId: any(named: 'providerKindId'),
          model: any(named: 'model'),
          apiKey: any(named: 'apiKey'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      expect(find.byType(SecretField), findsOneWidget);

      final saveButtonFinder = find.byKey(const Key('ai-settings-save-button'));
      expect(tester.widget<FilledButton>(saveButtonFinder).onPressed, isNull);

      await preencherFormulario(tester);
      expect(
        tester.widget<FilledButton>(saveButtonFinder).onPressed,
        isNotNull,
      );

      await tester.tap(saveButtonFinder);
      await tester.pump();

      expect(tester.widget<FilledButton>(saveButtonFinder).onPressed, isNull);
      expect(find.text('Salvando…'), findsOneWidget);

      completer.complete(
        const Right(
          AiCredential(
            id: 'c1',
            providerKindId: 'p1',
            model: modelDigitado,
            keyLast4: '4242',
            isActive: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('um erro de servidor preserva o que foi digitado', (
    tester,
  ) async {
    const failure = NetworkFailure();
    when(
      () => saveCredential(
        providerKindId: any(named: 'providerKindId'),
        model: any(named: 'model'),
        apiKey: any(named: 'apiKey'),
      ),
    ).thenAnswer((_) async => const Left(failure));

    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();
    await preencherFormulario(tester);

    await tester.tap(find.byKey(const Key('ai-settings-save-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining(failure.message), findsOneWidget);
    expect(find.text(modelDigitado), findsOneWidget);
    expect(find.text(chaveDigitada), findsOneWidget);
  });
}
