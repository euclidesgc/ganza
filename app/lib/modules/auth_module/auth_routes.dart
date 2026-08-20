import 'package:go_router/go_router.dart';

import 'presentation/login/login_page.dart';
import 'presentation/password_recovery/password_recovery_code_page.dart';
import 'presentation/password_recovery/password_recovery_request_page.dart';
import 'presentation/sign_up/sign_up_page.dart';

abstract final class AuthRoutes {
  static const loginName = 'login';
  static const loginPath = '/entrar';

  static const signUpName = 'signUp';
  static const signUpPath = '/cadastrar';

  static const passwordRecoveryRequestName = 'passwordRecoveryRequest';
  static const passwordRecoveryRequestPath = '/recuperar-senha';

  static const passwordRecoveryCodeName = 'passwordRecoveryCode';
  static const passwordRecoveryCodePath = '/recuperar-senha/codigo';

  static GoRoute get route =>
      GoRoute(path: loginPath, name: loginName, builder: LoginPage.pageBuilder);

  static GoRoute get signUpRoute => GoRoute(
    path: signUpPath,
    name: signUpName,
    builder: SignUpPage.pageBuilder,
  );

  static GoRoute get passwordRecoveryRequestRoute => GoRoute(
    path: passwordRecoveryRequestPath,
    name: passwordRecoveryRequestName,
    builder: PasswordRecoveryRequestPage.pageBuilder,
  );

  static GoRoute get passwordRecoveryCodeRoute => GoRoute(
    path: passwordRecoveryCodePath,
    name: passwordRecoveryCodeName,
    builder: PasswordRecoveryCodePage.pageBuilder,
  );
}
