import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/app_router.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/core/session/session.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/injection.dart';
import 'package:ganza/modules/auth_module/auth_module.dart';
import 'package:ganza/modules/chat_module/chat_module.dart';
import 'package:ganza/modules/chat_module/presentation/chat/chat_page.dart';
import 'package:ganza/modules/settings_module/domain/domain.dart';
import 'package:ganza/modules/settings_module/presentation/ai/ai_settings_cubit.dart';
import 'package:ganza/modules/settings_module/presentation/ai/settings_ai_page.dart';
import 'package:ganza/modules/settings_module/settings_module.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockObserveCurrentUser extends Mock implements ObserveCurrentUser {}

class _MockGetCurrentUser extends Mock implements GetCurrentUser {}

class _MockGetAiProviderKinds extends Mock implements GetAiProviderKinds {}

class _MockGetAiCredential extends Mock implements GetAiCredential {}

class _MockSaveAiCredential extends Mock implements SaveAiCredential {}

class _FakeCapabilitiesSource implements CapabilitiesSource {
  bool aiConfigured = false;

  @override
  Future<Either<Failure, UserCapabilities>> load() async =>
      Right(UserCapabilities(aiConfigured: aiConfigured, bankConnected: false));
}

void main() {
  late _FakeCapabilitiesSource source;
  late CapabilitiesCubit capabilities;

  setUp(() {
    final observeCurrentUser = _MockObserveCurrentUser();
    final getCurrentUser = _MockGetCurrentUser();
    when(() => observeCurrentUser()).thenAnswer((_) => const Stream.empty());
    when(
      () => getCurrentUser(),
    ).thenReturn(const AuthenticatedUser(id: 'u1', email: 'gate@ganza.local'));

    source = _FakeCapabilitiesSource();
    capabilities = CapabilitiesCubit(source);

    final getProviderKinds = _MockGetAiProviderKinds();
    final getCredential = _MockGetAiCredential();
    final saveCredential = _MockSaveAiCredential();
    when(() => getProviderKinds()).thenAnswer((_) async => const Right([]));
    when(() => getCredential()).thenAnswer((_) async => const Right(null));

    getIt
      ..registerLazySingleton<ObserveCurrentUser>(() => observeCurrentUser)
      ..registerLazySingleton<GetCurrentUser>(() => getCurrentUser)
      ..registerLazySingleton<PasswordRecoveryScope>(PasswordRecoveryScope.new)
      ..registerLazySingleton<CapabilitiesCubit>(() => capabilities)
      ..registerLazySingleton<GetAiProviderKinds>(() => getProviderKinds)
      ..registerLazySingleton<GetAiCredential>(() => getCredential)
      ..registerLazySingleton<SaveAiCredential>(() => saveCredential)
      ..registerFactory(
        () => AiSettingsCubit(
          getIt<GetAiProviderKinds>(),
          getIt<GetAiCredential>(),
          getIt<SaveAiCredential>(),
        ),
      );
  });

  tearDown(getIt.reset);

  Widget envolver(GoRouter roteador) =>
      MaterialApp.router(theme: AppTheme.light, routerConfig: roteador);

  testWidgets(
    'o gate de /chat barra sem IA configurada, libera ao configurar e volta '
    'a barrar ao apagar a credencial -- as três transições, mesma instância',
    (tester) async {
      final router = createRouter(initialLocation: ChatRoutes.path);
      await tester.pumpWidget(envolver(router));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsAiPage), findsOneWidget);
      expect(find.byType(ChatPage), findsNothing);
      expect(
        GoRouterState.of(
          tester.element(find.byType(SettingsAiPage)),
        ).uri.toString(),
        SettingsRoutes.aiFullPath,
      );

      source.aiConfigured = true;
      await capabilities.refresh();
      await tester.pumpAndSettle();

      expect(find.byType(ChatPage), findsOneWidget);
      expect(find.byType(SettingsAiPage), findsNothing);
      expect(
        GoRouterState.of(tester.element(find.byType(ChatPage))).uri.toString(),
        ChatRoutes.path,
      );

      source.aiConfigured = false;
      await capabilities.refresh();
      await tester.pumpAndSettle();

      expect(find.byType(SettingsAiPage), findsOneWidget);
      expect(find.byType(ChatPage), findsNothing);
    },
  );
}
