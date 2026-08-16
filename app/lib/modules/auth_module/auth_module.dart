export 'auth_injection.dart';
export 'auth_routes.dart';

/// Autenticação é transversal: a guarda de rota da raiz e qualquer tela com
/// "sair" precisam do estado da sessão. Por isso este barrel expõe, além da
/// rota e do DI, o contrato de sessão — e **só ele**. Repositório, models,
/// cubits e páginas continuam internos.
export 'domain/entities/authenticated_user.dart';
export 'domain/usecases/get_current_user.dart';
export 'domain/usecases/observe_current_user.dart';
export 'domain/usecases/sign_out.dart';
