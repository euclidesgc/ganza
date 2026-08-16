import '../entities/authenticated_user.dart';
import '../repositories/auth_repository.dart';

/// Síncrono de propósito: o `redirect` do go_router roda a cada navegação e
/// não pode esperar por um Future para decidir se a tela é permitida.
class GetCurrentUser {
  const GetCurrentUser(this._repository);

  final AuthRepository _repository;

  AuthenticatedUser? call() => _repository.currentUser;
}
