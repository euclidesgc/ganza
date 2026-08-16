import 'package:go_router/go_router.dart';

import 'presentation/login/login_page.dart';

abstract final class AuthRoutes {
  static const loginName = 'login';
  static const loginPath = '/entrar';

  static GoRoute get route =>
      GoRoute(path: loginPath, name: loginName, builder: LoginPage.pageBuilder);
}
