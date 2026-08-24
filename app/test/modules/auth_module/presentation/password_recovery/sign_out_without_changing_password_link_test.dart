import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/session/session.dart';
import 'package:ganza/modules/auth_module/auth_routes.dart';
import 'package:ganza/modules/auth_module/domain/usecases/sign_out.dart';
import 'package:ganza/modules/auth_module/domain/usecases/update_password.dart';
import 'package:ganza/modules/auth_module/domain/usecases/verify_recovery_code.dart';
import 'package:ganza/modules/auth_module/presentation/password_recovery/password_recovery_code_cubit.dart';
import 'package:ganza/modules/auth_module/presentation/password_recovery/widgets/sign_out_without_changing_password_link.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockVerifyRecoveryCode extends Mock implements VerifyRecoveryCode {}

class _MockUpdatePassword extends Mock implements UpdatePassword {}

class _MockSignOut extends Mock implements SignOut {}

void main() {
  testWidgets(
    'sair encerra a sessão antes de desligar o escopo e leva ao login',
    (tester) async {
      final scope = PasswordRecoveryScope();
      var scopeActiveDuringSignOut = false;
      final signOut = _MockSignOut();
      when(() => signOut()).thenAnswer((_) async {
        scopeActiveDuringSignOut = scope.isActive;
        return const Right(unit);
      });
      final cubit = PasswordRecoveryCodeCubit(
        _MockVerifyRecoveryCode(),
        _MockUpdatePassword(),
        signOut,
        scope,
      );
      expect(scope.isActive, isTrue);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: AuthRoutes.loginPath,
            name: AuthRoutes.loginName,
            builder: (_, _) => const Scaffold(body: Text('entrar')),
          ),
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(body: SignOutWithoutChangingPasswordLink()),
          ),
        ],
      );

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('Sair sem trocar a senha'));
      await tester.pumpAndSettle();

      expect(scopeActiveDuringSignOut, isTrue);
      expect(scope.isActive, isFalse);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        AuthRoutes.loginPath,
      );
    },
  );
}
