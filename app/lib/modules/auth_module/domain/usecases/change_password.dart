import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/auth_repository.dart';

class ChangePassword {
  const ChangePassword(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String currentPassword,
    required String newPassword,
  }) {
    if (currentPassword.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Informe a senha atual.')),
      );
    }
    if (newPassword.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Informe a nova senha.')),
      );
    }
    return _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}
