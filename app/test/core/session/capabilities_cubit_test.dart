import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/error.dart';
import 'package:ganza/core/session/session.dart';
import 'package:mocktail/mocktail.dart';

class _MockCapabilitiesSource extends Mock implements CapabilitiesSource {}

void main() {
  late _MockCapabilitiesSource source;

  CapabilitiesCubit build() => CapabilitiesCubit(source);

  setUp(() {
    source = _MockCapabilitiesSource();
  });

  group('refresh', () {
    test('fonte que devolve Left resulta em IA configurada false', () async {
      when(
        () => source.load(),
      ).thenAnswer((_) async => const Left(NetworkFailure()));

      final cubit = build();
      await cubit.refresh();

      expect(cubit.state.capabilities.aiConfigured, isFalse);
    });

    test('fonte que devolve Right repassa as capacidades lidas', () async {
      const capabilities = UserCapabilities(
        aiConfigured: true,
        bankConnected: false,
      );
      when(
        () => source.load(),
      ).thenAnswer((_) async => const Right(capabilities));

      final cubit = build();
      await cubit.refresh();

      expect(cubit.state.capabilities, capabilities);
    });
  });
}
