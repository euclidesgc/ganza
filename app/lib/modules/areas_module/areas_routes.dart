import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'presentation/areas/areas_page.dart';

abstract final class AreasRoutes {
  // A raiz também é alcançável pelo item Início do menu lateral.
  static const name = 'areas';
  static const path = '/';

  static GoRoute get route =>
      GoRoute(path: path, name: name, builder: AreasPage.pageBuilder);

  static void goNamed(BuildContext context) => context.goNamed(name);
}
