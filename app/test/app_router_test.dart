import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/app_router.dart';
import 'package:ganza/core/session/session.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/injection.dart';
import 'package:ganza/modules/areas_module/areas_module.dart';
import 'package:ganza/modules/areas_module/domain/domain.dart';
import 'package:ganza/modules/areas_module/presentation/areas/areas_cubit.dart';
import 'package:ganza/modules/areas_module/presentation/areas/widgets/areas_body.dart';
import 'package:ganza/modules/auth_module/auth_module.dart';
import 'package:ganza/modules/auth_module/domain/usecases/change_password.dart';
import 'package:ganza/modules/auth_module/presentation/change_password/change_password_cubit.dart';
import 'package:ganza/modules/auth_module/presentation/change_password/change_password_page.dart';
import 'package:ganza/modules/settings_module/domain/domain.dart';
import 'package:ganza/modules/settings_module/presentation/account/account_cubit.dart';
import 'package:ganza/modules/settings_module/settings_module.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockObserveCurrentUser extends Mock implements ObserveCurrentUser {}

class _MockGetCurrentUser extends Mock implements GetCurrentUser {}

class _MockListActiveAreas extends Mock implements ListActiveAreas {}

class _MockGetUserProfile extends Mock implements GetUserProfile {}

class _MockUpdateDisplayName extends Mock implements UpdateDisplayName {}

class _MockChangePassword extends Mock implements ChangePassword {}

void main() {
  setUp(() {
    final observeCurrentUser = _MockObserveCurrentUser();
    final getCurrentUser = _MockGetCurrentUser();
    when(() => observeCurrentUser()).thenAnswer((_) => const Stream.empty());
    when(
      () => getCurrentUser(),
    ).thenReturn(const AuthenticatedUser(id: 'u1', email: 'e2e@ganza.local'));

    final listActiveAreas = _MockListActiveAreas();
    when(
      () => listActiveAreas(),
    ).thenAnswer((_) async => const Right(<Area>[]));

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

    final changePassword = _MockChangePassword();

    getIt
      ..registerLazySingleton<ObserveCurrentUser>(() => observeCurrentUser)
      ..registerLazySingleton<GetCurrentUser>(() => getCurrentUser)
      ..registerLazySingleton<PasswordRecoveryScope>(PasswordRecoveryScope.new)
      ..registerLazySingleton<ListActiveAreas>(() => listActiveAreas)
      ..registerFactory(() => AreasCubit(getIt<ListActiveAreas>()))
      ..registerLazySingleton<GetUserProfile>(() => getUserProfile)
      ..registerLazySingleton<UpdateDisplayName>(() => updateDisplayName)
      ..registerFactory(
        () => AccountCubit(getIt<GetUserProfile>(), getIt<UpdateDisplayName>()),
      )
      ..registerLazySingleton<ChangePassword>(() => changePassword)
      ..registerFactory(() => ChangePasswordCubit(getIt<ChangePassword>()));
  });

  tearDown(getIt.reset);

  Widget envolver(GoRouter roteador) =>
      MaterialApp.router(theme: AppTheme.light, routerConfig: roteador);

  testWidgets(
    'voltar duas vezes a partir de /configuracoes/conta/senha chega à '
    'lista de áreas',
    (tester) async {
      final router = createRouter(initialLocation: AreasRoutes.path);
      await tester.pumpWidget(envolver(router));
      await tester.pumpAndSettle();

      expect(find.byType(AreasBody), findsOneWidget);

      router.pushNamed(SettingsRoutes.accountName);
      await tester.pumpAndSettle();

      router.pushNamed(AuthRoutes.changePasswordName);
      await tester.pumpAndSettle();

      expect(find.byType(AreasBody), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(AreasBody), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(AreasBody), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    },
  );

  testWidgets(
    'a partir da tela inicial, drawer > Configurações > Conta > Trocar '
    'senha chega a /configuracoes/conta/senha',
    (tester) async {
      final router = createRouter();
      await tester.pumpWidget(envolver(router));
      await tester.pumpAndSettle();

      expect(find.byType(AreasBody), findsOneWidget);

      await tester.tap(find.byTooltip('Abrir menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Configurações'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Conta'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Trocar senha'));
      await tester.tap(find.text('Trocar senha'));
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordPage), findsOneWidget);
      expect(
        GoRouterState.of(
          tester.element(find.byType(ChangePasswordPage)),
        ).uri.toString(),
        AuthRoutes.changePasswordPath,
      );
    },
  );
}
