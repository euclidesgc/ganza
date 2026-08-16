import 'package:go_router/go_router.dart';

import 'presentation/home/home_page.dart';

abstract final class HomeRoutes {
  static const name = 'home';
  static const path = '/';

  static GoRoute get route =>
      GoRoute(path: path, name: name, builder: HomePage.pageBuilder);
}
