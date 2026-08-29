import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/auth_repository.dart';
import '../repositories/biometric_login_service.dart';

class SignOut {
  const SignOut(this._repository, this._biometricLogin);

  final AuthRepository _repository;
  final BiometricLoginService _biometricLogin;

  Future<Either<Failure, Unit>> call() async {
    final result = await _repository.signOut();
    if (result.isRight()) {
      try {
        await _biometricLogin.disable();
      } catch (_) {
        // O logout global já invalidou a sessão no GoTrue. Não transformar
        // uma falha no cofre local em erro mantém os fluxos sensíveis, como a
        // recuperação de senha, capazes de concluir o redirecionamento.
      }
    }
    return result;
  }
}
