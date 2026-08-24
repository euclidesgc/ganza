import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/app_router.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/core/session/session.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/core/widgets/widgets.dart';
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
import 'package:ganza/modules/settings_module/presentation/ai/ai_settings_cubit.dart';
import 'package:ganza/modules/settings_module/presentation/ai/settings_ai_page.dart';
import 'package:ganza/modules/settings_module/presentation/bank/bank_settings_cubit.dart';
import 'package:ganza/modules/settings_module/presentation/bank/settings_bank_page.dart';
import 'package:ganza/modules/settings_module/settings_module.dart';
import 'package:ganza/modules/transactions_module/domain/entities/category.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/categorize_transaction.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/list_categories.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/list_transactions.dart';
import 'package:ganza/modules/transactions_module/presentation/transactions_list/transactions_list_cubit.dart';
import 'package:ganza/modules/transactions_module/presentation/transactions_list/transactions_list_page.dart';
import 'package:ganza/modules/transactions_module/transactions_module.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockObserveCurrentUser extends Mock implements ObserveCurrentUser {}

class _MockGetCurrentUser extends Mock implements GetCurrentUser {}

class _MockListActiveAreas extends Mock implements ListActiveAreas {}

class _MockListTransactions extends Mock implements ListTransactions {}

class _MockListCategories extends Mock implements ListCategories {}

class _MockCategorizeTransaction extends Mock
    implements CategorizeTransaction {}

class _MockGetUserProfile extends Mock implements GetUserProfile {}

class _MockUpdateDisplayName extends Mock implements UpdateDisplayName {}

class _MockChangePassword extends Mock implements ChangePassword {}

class _MockGetAiProviderKinds extends Mock implements GetAiProviderKinds {}

class _MockGetAiCredential extends Mock implements GetAiCredential {}

class _MockSaveAiCredential extends Mock implements SaveAiCredential {}

class _MockGetBankConnection extends Mock implements GetBankConnection {}

class _MockStartBankConnection extends Mock implements StartBankConnection {}

class _MockDisconnectBankConnection extends Mock
    implements DisconnectBankConnection {}

class _FakeCapabilitiesSource implements CapabilitiesSource {
  _FakeCapabilitiesSource({required this.aiConfigured});

  final bool aiConfigured;

  @override
  Future<Either<Failure, UserCapabilities>> load() async =>
      Right(UserCapabilities(aiConfigured: aiConfigured, bankConnected: false));
}

void main() {
  late bool aiConfigured;
  late StreamController<AuthenticatedUser?> sessionController;

  setUp(() {
    final observeCurrentUser = _MockObserveCurrentUser();
    final getCurrentUser = _MockGetCurrentUser();
    sessionController = StreamController<AuthenticatedUser?>.broadcast();
    when(
      () => observeCurrentUser(),
    ).thenAnswer((_) => sessionController.stream);
    when(
      () => getCurrentUser(),
    ).thenReturn(const AuthenticatedUser(id: 'u1', email: 'e2e@ganza.local'));

    final listActiveAreas = _MockListActiveAreas();
    when(
      () => listActiveAreas(),
    ).thenAnswer((_) async => const Right(<Area>[]));

    final listTransactions = _MockListTransactions();
    when(
      () => listTransactions(),
    ).thenAnswer((_) async => const Right(<Transaction>[]));

    final listCategories = _MockListCategories();
    when(
      () => listCategories(),
    ).thenAnswer((_) async => const Right(<Category>[]));
    final categorizeTransaction = _MockCategorizeTransaction();

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

    aiConfigured = false;
    final getProviderKinds = _MockGetAiProviderKinds();
    final getCredential = _MockGetAiCredential();
    final saveCredential = _MockSaveAiCredential();
    when(() => getProviderKinds()).thenAnswer((_) async => const Right([]));
    when(() => getCredential()).thenAnswer((_) async => const Right(null));

    final getBankConnection = _MockGetBankConnection();
    final startBankConnection = _MockStartBankConnection();
    final disconnectBankConnection = _MockDisconnectBankConnection();
    when(() => getBankConnection()).thenAnswer((_) async => const Right(null));

    getIt
      ..registerLazySingleton<ObserveCurrentUser>(() => observeCurrentUser)
      ..registerLazySingleton<GetCurrentUser>(() => getCurrentUser)
      ..registerLazySingleton<PasswordRecoveryScope>(PasswordRecoveryScope.new)
      ..registerLazySingleton<ListActiveAreas>(() => listActiveAreas)
      ..registerFactory(() => AreasCubit(getIt<ListActiveAreas>()))
      ..registerLazySingleton<ListTransactions>(() => listTransactions)
      ..registerLazySingleton<ListCategories>(() => listCategories)
      ..registerLazySingleton<CategorizeTransaction>(
        () => categorizeTransaction,
      )
      ..registerFactory(
        () => TransactionsListCubit(
          getIt<ListTransactions>(),
          getIt<ListCategories>(),
          getIt<CategorizeTransaction>(),
        ),
      )
      ..registerLazySingleton<GetUserProfile>(() => getUserProfile)
      ..registerLazySingleton<UpdateDisplayName>(() => updateDisplayName)
      ..registerFactory(
        () => AccountCubit(getIt<GetUserProfile>(), getIt<UpdateDisplayName>()),
      )
      ..registerLazySingleton<ChangePassword>(() => changePassword)
      ..registerFactory(() => ChangePasswordCubit(getIt<ChangePassword>()))
      ..registerLazySingleton<CapabilitiesCubit>(
        () => CapabilitiesCubit(
          _FakeCapabilitiesSource(aiConfigured: aiConfigured),
        )..refresh(),
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
      ..registerLazySingleton<GetBankConnection>(() => getBankConnection)
      ..registerLazySingleton<StartBankConnection>(() => startBankConnection)
      ..registerLazySingleton<DisconnectBankConnection>(
        () => disconnectBankConnection,
      )
      ..registerFactory(
        () => BankSettingsCubit(
          getIt<GetBankConnection>(),
          getIt<StartBankConnection>(),
          getIt<DisconnectBankConnection>(),
        ),
      );
  });

  tearDown(() {
    sessionController.close();
    getIt.reset();
  });

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

  testWidgets('com a IA não configurada, drawer > Configurações > IA chega '
      'utilizável a /configuracoes/ia', (tester) async {
    aiConfigured = false;
    final router = createRouter();
    await tester.pumpWidget(envolver(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Abrir menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('IA'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsAiPage), findsOneWidget);
    expect(find.byType(SecretField), findsOneWidget);
    expect(
      GoRouterState.of(
        tester.element(find.byType(SettingsAiPage)),
      ).uri.toString(),
      SettingsRoutes.aiFullPath,
    );
  });

  testWidgets('com a IA já configurada, drawer > Configurações > IA chega '
      'utilizável a /configuracoes/ia', (tester) async {
    aiConfigured = true;
    final router = createRouter();
    await tester.pumpWidget(envolver(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Abrir menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('IA'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsAiPage), findsOneWidget);
    expect(find.byType(SecretField), findsOneWidget);
    expect(
      GoRouterState.of(
        tester.element(find.byType(SettingsAiPage)),
      ).uri.toString(),
      SettingsRoutes.aiFullPath,
    );
  });

  testWidgets(
    'a partir da tela inicial, drawer > Configurações > Banco chega a '
    '/configuracoes/banco sem o placeholder',
    (tester) async {
      final router = createRouter();
      await tester.pumpWidget(envolver(router));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Abrir menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Configurações'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Banco'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsBankPage), findsOneWidget);
      expect(find.byType(PlaceholderBody), findsNothing);
      expect(
        GoRouterState.of(
          tester.element(find.byType(SettingsBankPage)),
        ).uri.toString(),
        '${SettingsRoutes.path}/${SettingsRoutes.bankPath}',
      );
    },
  );

  testWidgets('drawer chega a transações e voltar preserva a pilha', (
    tester,
  ) async {
    final router = createRouter();
    await tester.pumpWidget(envolver(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Abrir menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transações'));
    await tester.pumpAndSettle();

    expect(
      GoRouterState.of(
        tester.element(find.byType(TransactionsListPage)),
      ).uri.toString(),
      TransactionsRoutes.path,
    );

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(AreasBody), findsOneWidget);
  });

  testWidgets('trocar a senha logado não desloga nem navega', (tester) async {
    final changePassword = getIt<ChangePassword>();
    when(
      () => changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async => const Right(unit));

    final router = createRouter(initialLocation: AuthRoutes.changePasswordPath);
    await tester.pumpWidget(envolver(router));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('change-password-current-field')),
      'senhaAtual123',
    );
    await tester.enterText(
      find.byKey(const Key('change-password-new-field')),
      'senhaNova123',
    );
    await tester.enterText(
      find.byKey(const Key('change-password-confirm-field')),
      'senhaNova123',
    );
    await tester.pumpAndSettle();

    sessionController.add(
      const AuthenticatedUser(id: 'u1', email: 'e2e@ganza.local'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('change-password-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordPage), findsOneWidget);
    expect(
      GoRouterState.of(
        tester.element(find.byType(ChangePasswordPage)),
      ).uri.toString(),
      AuthRoutes.changePasswordPath,
    );
  });
}
