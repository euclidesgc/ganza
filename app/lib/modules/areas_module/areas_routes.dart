import 'package:go_router/go_router.dart';

import 'presentation/areas/areas_page.dart';

abstract final class AreasRoutes {
  static const name = 'areas';
  static const path = '/';

  static GoRoute get route =>
      GoRoute(path: path, name: name, builder: AreasPage.pageBuilder);
}
