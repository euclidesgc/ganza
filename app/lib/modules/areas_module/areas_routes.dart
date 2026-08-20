import 'package:go_router/go_router.dart';

import 'presentation/areas/areas_page.dart';

abstract final class AreasRoutes {
  static const name = 'areas'; // rota-sem-consumidor-ok: raiz alcançada só pelo redirect da guarda de sessão (initialLocation e fallback em app_router.dart), nunca por toque
  static const path = '/';

  static GoRoute get route =>
      GoRoute(path: path, name: name, builder: AreasPage.pageBuilder);
}
