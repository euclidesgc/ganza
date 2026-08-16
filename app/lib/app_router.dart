import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'injection.dart';
import 'modules/areas_module/areas_module.dart';
import 'modules/auth_module/auth_module.dart';

/// Sem `extra:` em nenhuma rota — ele some no refresh do navegador, e o
/// mesmo `lib/` serve Android e Web.
GoRouter createRouter() {
  final sessions = getIt<ObserveCurrentUser>()();

  return GoRouter(
    initialLocation: AreasRoutes.path,
    refreshListenable: _SessionListenable(sessions),
    redirect: (context, state) {
      final signedIn = getIt<GetCurrentUser>()() != null;
      final goingToLogin = state.matchedLocation == AuthRoutes.loginPath;

      if (!signedIn && !goingToLogin) return AuthRoutes.loginPath;
      if (signedIn && goingToLogin) return AreasRoutes.path;
      return null;
    },
    routes: [AreasRoutes.route, AuthRoutes.route],
  );
}

/// O go_router só reavalia o `redirect` quando algo o notifica. Sem isto, o
/// login entra e a tela não troca até uma navegação manual.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Stream<AuthenticatedUser?> sessions) {
    _subscription = sessions.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthenticatedUser?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
