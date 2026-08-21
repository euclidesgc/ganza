import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/settings_module/domain/domain.dart';
import 'package:ganza/modules/settings_module/presentation/ai/ai_settings_cubit.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetAiProviderKinds extends Mock implements GetAiProviderKinds {}

class _MockGetAiCredential extends Mock implements GetAiCredential {}

class _MockSaveAiCredential extends Mock implements SaveAiCredential {}

void main() {
  late _MockGetAiProviderKinds getProviderKinds;
  late _MockGetAiCredential getCredential;
  late _MockSaveAiCredential saveCredential;

  const providerKinds = [
    AiProviderKind(id: 'p1', slug: 'gemini', label: 'Google Gemini'),
  ];
  const credential = AiCredential(
    id: 'c1',
    providerKindId: 'p1',
    model: 'gemini-2.0-flash',
    keyLast4: 'ABCD',
    isActive: true,
  );

  AiSettingsCubit build() =>
      AiSettingsCubit(getProviderKinds, getCredential, saveCredential);

  void stubSave(Either<Failure, AiCredential> result) {
    when(
      () => saveCredential(
        providerKindId: any(named: 'providerKindId'),
        model: any(named: 'model'),
        apiKey: any(named: 'apiKey'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    getProviderKinds = _MockGetAiProviderKinds();
    getCredential = _MockGetAiCredential();
    saveCredential = _MockSaveAiCredential();
  });

  group('load', () {
    test(
      'catálogo e credencial carregados resultam em AiSettingsReady',
      () async {
        when(
          () => getProviderKinds(),
        ).thenAnswer((_) async => const Right(providerKinds));
        when(
          () => getCredential(),
        ).thenAnswer((_) async => const Right(credential));

        final cubit = build();
        await cubit.load();

        final state = cubit.state;
        expect(state, isA<AiSettingsReady>());
        expect((state as AiSettingsReady).credential, credential);
        expect(state.providerKinds, providerKinds);
        await cubit.close();
      },
    );

    test(
      'falha ao carregar o catálogo resulta em AiSettingsLoadFailed',
      () async {
        when(
          () => getProviderKinds(),
        ).thenAnswer((_) async => const Left(NetworkFailure()));

        final cubit = build();
        await cubit.load();

        expect(cubit.state, isA<AiSettingsLoadFailed>());
        verifyNever(() => getCredential());
        await cubit.close();
      },
    );

    test(
      'falha ao carregar a credencial resulta em AiSettingsLoadFailed',
      () async {
        when(
          () => getProviderKinds(),
        ).thenAnswer((_) async => const Right(providerKinds));
        when(
          () => getCredential(),
        ).thenAnswer((_) async => const Left(UnexpectedFailure()));

        final cubit = build();
        await cubit.load();

        expect(cubit.state, isA<AiSettingsLoadFailed>());
        await cubit.close();
      },
    );
  });

  group('save', () {
    test('sucesso resulta em AiSettingsReady com a credencial salva', () async {
      when(
        () => getProviderKinds(),
      ).thenAnswer((_) async => const Right(providerKinds));
      when(() => getCredential()).thenAnswer((_) async => const Right(null));
      stubSave(const Right(credential));

      final cubit = build();
      await cubit.load();
      await cubit.save(
        providerKindId: 'p1',
        model: 'gemini-2.0-flash',
        apiKey: 'sk-test',
      );

      final state = cubit.state;
      expect(state, isA<AiSettingsReady>());
      expect((state as AiSettingsReady).credential, credential);
      await cubit.close();
    });

    test(
      'falha ao salvar resulta em AiSettingsSaveFailed preservando o catálogo',
      () async {
        when(
          () => getProviderKinds(),
        ).thenAnswer((_) async => const Right(providerKinds));
        when(() => getCredential()).thenAnswer((_) async => const Right(null));
        const failure = ValidationFailure('Informe provedor, modelo e chave.');
        stubSave(const Left(failure));

        final cubit = build();
        await cubit.load();
        await cubit.save(
          providerKindId: 'p1',
          model: 'gemini-2.0-flash',
          apiKey: 'sk-test',
        );

        final state = cubit.state;
        expect(state, isA<AiSettingsSaveFailed>());
        expect((state as AiSettingsSaveFailed).failure, failure);
        expect(state.providerKinds, providerKinds);
        await cubit.close();
      },
    );

    test(
      'fechar o cubit antes do use case completar não emite novo estado nem deixa exceção escapar',
      () async {
        when(
          () => getProviderKinds(),
        ).thenAnswer((_) async => const Right(providerKinds));
        when(() => getCredential()).thenAnswer((_) async => const Right(null));

        final completer = Completer<Either<Failure, AiCredential>>();
        when(
          () => saveCredential(
            providerKindId: any(named: 'providerKindId'),
            model: any(named: 'model'),
            apiKey: any(named: 'apiKey'),
          ),
        ).thenAnswer((_) => completer.future);

        final cubit = build();
        await cubit.load();

        final states = <AiSettingsState>[];
        final subscription = cubit.stream.listen(states.add);

        final saveFuture = cubit.save(
          providerKindId: 'p1',
          model: 'gemini-2.0-flash',
          apiKey: 'sk-test',
        );
        await Future<void>.delayed(Duration.zero);
        await cubit.close();

        completer.complete(const Right(credential));

        await expectLater(saveFuture, completes);
        await subscription.cancel();

        expect(states, [isA<AiSettingsSaving>()]);
      },
    );
  });
}
