import 'package:go_router/go_router.dart';

import 'modules/home_module/home_module.dart';

/// Sem `extra:` em nenhuma rota — ele some no refresh do navegador, e o
/// mesmo `lib/` serve Android e Web.
GoRouter createRouter() {
  return GoRouter(initialLocation: HomeRoutes.path, routes: [HomeRoutes.route]);
}
