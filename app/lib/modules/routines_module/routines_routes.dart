import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'presentation/routines/routines_page.dart';

abstract final class RoutinesRoutes {
  static const name = 'routines';
  static const path = '/rotinas';

  static GoRoute get route =>
      GoRoute(path: path, name: name, builder: RoutinesPage.pageBuilder);

  static void pushNamed(BuildContext context) => context.pushNamed(name);
}
