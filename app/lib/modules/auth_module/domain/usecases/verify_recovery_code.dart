import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/auth_repository.dart';

class VerifyRecoveryCode {
  const VerifyRecoveryCode(this._repository);

  static final _sixDigitsCode = RegExp(r'^\d{6}$');

  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String email,
    required String token,
  }) {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || !_sixDigitsCode.hasMatch(token)) {
      return Future.value(
        const Left(ValidationFailure('Informe o código de seis dígitos.')),
      );
    }
    return _repository.verifyRecoveryCode(email: normalizedEmail, token: token);
  }
}
