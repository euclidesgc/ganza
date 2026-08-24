import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'presentation/commitments/commitments_page.dart';

abstract final class CommitmentsRoutes {
  static const name = 'commitments';
  static const path = '/compromissos';

  static GoRoute get route =>
      GoRoute(path: path, name: name, builder: CommitmentsPage.pageBuilder);

  static void pushNamed(BuildContext context) => context.pushNamed(name);
}
