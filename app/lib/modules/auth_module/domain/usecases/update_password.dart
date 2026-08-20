import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/auth_repository.dart';

class UpdatePassword {
  const UpdatePassword(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call({required String newPassword}) {
    if (newPassword.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Informe a nova senha.')),
      );
    }
    return _repository.updatePassword(newPassword: newPassword);
  }
}
