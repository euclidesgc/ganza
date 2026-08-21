import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/app_router.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/core/session/session.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/injection.dart';
import 'package:ganza/modules/auth_module/auth_module.dart';
import 'package:ganza/modules/settings_module/domain/domain.dart';
import 'package:ganza/modules/settings_module/presentation/account/account_cubit.dart';
import 'package:ganza/modules/settings_module/presentation/ai/ai_settings_cubit.dart';
import 'package:ganza/modules/settings_module/settings_module.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockObserveCurrentUser extends Mock implements ObserveCurrentUser {}

class _MockGetCurrentUser extends Mock implements GetCurrentUser {}

class _MockGetUserProfile extends Mock implements GetUserProfile {}

class _MockUpdateDisplayName extends Mock implements UpdateDisplayName {}

class _MockGetAiProviderKinds extends Mock implements GetAiProviderKinds {}

class _MockGetAiCredential extends Mock implements GetAiCredential {}

class _MockSaveAiCredential extends Mock implements SaveAiCredential {}

class _FakeCapabilitiesSource implements CapabilitiesSource {
  @override
  Future<Either<Failure, UserCapabilities>> load() async =>
      const Right(UserCapabilities.unresolved());
}

void main() {
  setUp(() {
    final observeCurrentUser = _MockObserveCurrentUser();
    final getCurrentUser = _MockGetCurrentUser();
    when(() => observeCurrentUser()).thenAnswer((_) => const Stream.empty());
    when(
      () => getCurrentUser(),
    ).thenReturn(const AuthenticatedUser(id: 'u1', email: 'e2e@ganza.local'));

    final getUserProfile = _MockGetUserProfile();
    final updateDisplayName = _MockUpdateDisplayName();
    when(() => getUserProfile()).thenAnswer(
      (_) async => const Right(
        UserProfile(
          id: 'u1',
          email: 'e2e@ganza.local',
          displayName: 'Pessoa Ganzá',
          timezone: 'America/Sao_Paulo',
        ),
      ),
    );

    final getProviderKinds = _MockGetAiProviderKinds();
    final getCredential = _MockGetAiCredential();
    final saveCredential = _MockSaveAiCredential();
    when(() => getProviderKinds()).thenAnswer((_) async => const Right([]));
    when(() => getCredential()).thenAnswer((_) async => const Right(null));

    getIt
      ..registerLazySingleton<ObserveCurrentUser>(() => observeCurrentUser)
      ..registerLazySingleton<GetCurrentUser>(() => getCurrentUser)
      ..registerLazySingleton<PasswordRecoveryScope>(PasswordRecoveryScope.new)
      ..registerLazySingleton<GetUserProfile>(() => getUserProfile)
      ..registerLazySingleton<UpdateDisplayName>(() => updateDisplayName)
      ..registerFactory(
        () => AccountCubit(getIt<GetUserProfile>(), getIt<UpdateDisplayName>()),
      )
      ..registerLazySingleton<GetAiProviderKinds>(() => getProviderKinds)
      ..registerLazySingleton<GetAiCredential>(() => getCredential)
      ..registerLazySingleton<SaveAiCredential>(() => saveCredential)
      ..registerFactory(
        () => AiSettingsCubit(
          getIt<GetAiProviderKinds>(),
          getIt<GetAiCredential>(),
          getIt<SaveAiCredential>(),
        ),
      )
      ..registerLazySingleton<CapabilitiesCubit>(
        () => CapabilitiesCubit(_FakeCapabilitiesSource())..refresh(),
      );
  });

  tearDown(getIt.reset);

  Widget envolver(GoRouter roteador) =>
      MaterialApp.router(theme: AppTheme.light, routerConfig: roteador);

  group('SettingsHomePage', () {
    testWidgets('lista as três seções com rótulo textual visível', (
      tester,
    ) async {
      await tester.pumpWidget(
        envolver(createRouter(initialLocation: SettingsRoutes.path)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Conta'), findsOneWidget);
      expect(find.text('IA'), findsOneWidget);
      expect(find.text('Banco'), findsOneWidget);
    });

    testWidgets('tocar em Conta navega para o destino sem lançar', (
      tester,
    ) async {
      await tester.pumpWidget(
        envolver(createRouter(initialLocation: SettingsRoutes.path)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Conta'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(AppBar, 'Conta'), findsOneWidget);
    });

    testWidgets('tocar em IA navega para o destino sem lançar', (tester) async {
      await tester.pumpWidget(
        envolver(createRouter(initialLocation: SettingsRoutes.path)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('IA'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(AppBar, 'IA'), findsOneWidget);
    });

    testWidgets('tocar em Banco navega para o destino sem lançar', (
      tester,
    ) async {
      await tester.pumpWidget(
        envolver(createRouter(initialLocation: SettingsRoutes.path)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Banco'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(AppBar, 'Banco'), findsOneWidget);
    });

    testWidgets(
      'em /configuracoes o drawer é alcançável e a AppBar não tem seta de voltar',
      (tester) async {
        await tester.pumpWidget(
          envolver(createRouter(initialLocation: SettingsRoutes.path)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BackButton), findsNothing);
        expect(find.byTooltip('Abrir menu'), findsOneWidget);

        await tester.tap(find.byTooltip('Abrir menu'));
        await tester.pumpAndSettle();

        expect(find.byType(Drawer), findsOneWidget);
      },
    );
  });
}
