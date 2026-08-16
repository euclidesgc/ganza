import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/authenticated_user.dart';
import '../repositories/auth_repository.dart';

class SignIn {
  const SignIn(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, AuthenticatedUser>> call({
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Informe e-mail e senha.')),
      );
    }
    return _repository.signIn(email: normalizedEmail, password: password);
  }
}
