import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/modules/settings_module/domain/domain.dart';
import 'package:ganza/modules/settings_module/presentation/account/account_cubit.dart';
import 'package:ganza/modules/settings_module/presentation/account/settings_account_page.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetUserProfile extends Mock implements GetUserProfile {}

class _MockUpdateDisplayName extends Mock implements UpdateDisplayName {}

void main() {
  late _MockGetUserProfile getUserProfile;
  late _MockUpdateDisplayName updateDisplayName;

  const perfil = UserProfile(
    id: 'u1',
    email: 'ana@ganza.local',
    displayName: 'Ana',
    timezone: 'America/Sao_Paulo',
  );

  setUp(() {
    getUserProfile = _MockGetUserProfile();
    updateDisplayName = _MockUpdateDisplayName();
    when(() => getUserProfile()).thenAnswer((_) async => const Right(perfil));
  });

  Widget montar() => MaterialApp(
    theme: AppTheme.light,
    home: BlocProvider<AccountCubit>(
      create: (_) => AccountCubit(getUserProfile, updateDisplayName)..load(),
      child: const SettingsAccountPage(),
    ),
  );

  group('SettingsAccountPage', () {
    testWidgets('o campo de e-mail é somente leitura e explica o motivo', (
      tester,
    ) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      final campoEmail = tester.widget<TextField>(
        find.byKey(const Key('account-email-field')),
      );
      expect(campoEmail.readOnly, isTrue);
      expect(
        find.textContaining('é preciso confirmar o novo endereço'),
        findsOneWidget,
      );
    });

    testWidgets('salvar com o nome vazio não chama o repositório', (
      tester,
    ) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('account-display-name-field')),
        '   ',
      );
      await tester.tap(find.byKey(const Key('account-save-button')));
      await tester.pumpAndSettle();

      verifyNever(
        () => updateDisplayName(displayName: any(named: 'displayName')),
      );
    });

    testWidgets('erro do servidor ao salvar preserva o nome digitado', (
      tester,
    ) async {
      when(
        () => updateDisplayName(displayName: any(named: 'displayName')),
      ).thenAnswer((_) async => const Left(UnexpectedFailure()));

      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('account-display-name-field')),
        'Novo Nome',
      );
      await tester.tap(find.byKey(const Key('account-save-button')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Novo Nome'), findsOneWidget);
    });
  });
}
