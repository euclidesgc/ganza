import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/auth_repository.dart';

class ResetPasswordForEmail {
  const ResetPasswordForEmail(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call({required String email}) {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      return Future.value(const Left(ValidationFailure('Informe o e-mail.')));
    }
    return _repository.resetPasswordForEmail(email: normalizedEmail);
  }
}
