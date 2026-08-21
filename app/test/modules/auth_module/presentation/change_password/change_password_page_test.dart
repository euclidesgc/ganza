import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/modules/auth_module/domain/usecases/change_password.dart';
import 'package:ganza/modules/auth_module/presentation/change_password/change_password_cubit.dart';
import 'package:ganza/modules/auth_module/presentation/change_password/change_password_page.dart';
import 'package:mocktail/mocktail.dart';

class _MockChangePassword extends Mock implements ChangePassword {}

void main() {
  late _MockChangePassword changePassword;

  setUp(() {
    changePassword = _MockChangePassword();
  });

  Widget montar() => MaterialApp(
    theme: AppTheme.light,
    home: BlocProvider<ChangePasswordCubit>(
      create: (_) => ChangePasswordCubit(changePassword),
      child: const ChangePasswordPage(),
    ),
  );

  group('ChangePasswordPage', () {
    testWidgets(
      'botão de confirmar fica desabilitado enquanto a nova senha e a '
      'confirmação diferem',
      (tester) async {
        await tester.pumpWidget(montar());
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
          'senhaNova124',
        );
        await tester.pumpAndSettle();

        final botao = tester.widget<FilledButton>(
          find.byKey(const Key('change-password-submit-button')),
        );
        expect(botao.onPressed, isNull);

        verifyNever(
          () => changePassword(
            currentPassword: any(named: 'currentPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        );
      },
    );

    testWidgets(
      'senha atual errada mostra mensagem curta e preserva nova senha e '
      'confirmação digitadas',
      (tester) async {
        when(
          () => changePassword(
            currentPassword: any(named: 'currentPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenAnswer(
          (_) async => const Left(AuthFailure('E-mail ou senha incorretos.')),
        );

        await tester.pumpWidget(montar());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('change-password-current-field')),
          'senhaErrada1',
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

        await tester.tap(
          find.byKey(const Key('change-password-submit-button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
        expect(
          find.widgetWithText(TextField, 'senhaNova123'),
          findsNWidgets(2),
        );
      },
    );
  });
}
