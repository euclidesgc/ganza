import '../entities/authenticated_user.dart';
import '../repositories/auth_repository.dart';

class ObserveCurrentUser {
  const ObserveCurrentUser(this._repository);

  final AuthRepository _repository;

  Stream<AuthenticatedUser?> call() => _repository.observeCurrentUser();
}
