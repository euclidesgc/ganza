import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import 'core/routing/routing.dart';
import 'core/session/session.dart';
import 'injection.dart';
import 'modules/areas_module/areas_module.dart';
import 'modules/auth_module/auth_module.dart';
import 'modules/chat_module/chat_module.dart';
import 'modules/routines_module/routines_module.dart';
import 'modules/settings_module/settings_module.dart';
import 'modules/transactions_module/transactions_module.dart';

/// Caminhos que só fazem sentido com IA configurada. O redirect desvia para
/// a própria tela que remove a barreira — nunca para fora dela.
const _aiGatedPaths = {ChatRoutes.path};

/// Sem `extra:` em nenhuma rota — ele some no refresh do navegador, e o
/// mesmo `lib/` serve Android e Web.
GoRouter createRouter({String initialLocation = AreasRoutes.path}) {
  final sessions = getIt<ObserveCurrentUser>()();
  final recoveryScope = getIt<PasswordRecoveryScope>();
  final capabilities = getIt<CapabilitiesCubit>();
  var pendingAiGatedDestination = '';

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    refreshListenable: Listenable.merge([
      _SessionListenable(sessions),
      recoveryScope,
      _CapabilitiesListenable(capabilities),
    ]),
    redirect: (context, state) {
      final location = state.matchedLocation;

      // O verifyOTP da recuperação de senha entrega uma sessão válida do
      // GoTrue, igual a um login normal. Sem este terceiro estado a guarda
      // trataria isso como sessão comum e mandaria para a raiz antes de o
      // usuário ver o campo de nova senha — PasswordRecoveryScope é o único
      // sinal que distingue os dois casos.
      if (recoveryScope.isActive) {
        return location == AuthRoutes.passwordRecoveryCodePath
            ? null
            : AuthRoutes.passwordRecoveryCodePath;
      }

      final signedIn = getIt<GetCurrentUser>()() != null;
      const publicPaths = {
        AuthRoutes.loginPath,
        AuthRoutes.signUpPath,
        AuthRoutes.passwordRecoveryRequestPath,
        AuthRoutes.passwordRecoveryCodePath,
      };

      if (!signedIn) {
        return publicPaths.contains(location) ? null : AuthRoutes.loginPath;
      }
      if (publicPaths.contains(location)) {
        return AreasRoutes.path;
      }
      final aiConfigured = capabilities.state.capabilities.aiConfigured;
      if (_aiGatedPaths.contains(location) && !aiConfigured) {
        pendingAiGatedDestination = location;
        return SettingsRoutes.aiFullPath;
      }
      // O redirect só derruba o usuário para a tela de IA; a volta ao
      // destino que ele pediu depende de o refreshListenable reavaliar
      // este mesmo caminho quando a credencial é salva — sem isso ele
      // fica preso na tela que acabou de preencher.
      if (pendingAiGatedDestination.isNotEmpty &&
          location == SettingsRoutes.aiFullPath &&
          aiConfigured) {
        final destination = pendingAiGatedDestination;
        pendingAiGatedDestination = '';
        return destination;
      }
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          AreasRoutes.route,
          ChatRoutes.route,
          RoutinesRoutes.route,
          SettingsRoutes.route,
          TransactionsRoutes.route,
        ],
      ),
      AuthRoutes.route,
      AuthRoutes.signUpRoute,
      AuthRoutes.passwordRecoveryRequestRoute,
      AuthRoutes.passwordRecoveryCodeRoute,
      AuthRoutes.changePasswordRoute,
    ],
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

/// Sem isto, salvar a chave de IA não reavalia o `redirect`: o usuário fica
/// preso na tela que acabou de preencher até navegar manualmente de novo.
class _CapabilitiesListenable extends ChangeNotifier {
  _CapabilitiesListenable(CapabilitiesCubit capabilities) {
    _subscription = capabilities.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<CapabilitiesState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
