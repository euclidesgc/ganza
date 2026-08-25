import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../data/biometric_login_service.dart';
import '../repositories/auth_repository.dart';

class SignOutLocally {
  const SignOutLocally(this._repository, this._biometricLogin);

  final AuthRepository _repository;
  final BiometricLoginService _biometricLogin;

  Future<Either<Failure, Unit>> call() async {
    // O Supabase pode rotacionar o refresh token enquanto o app está aberto.
    // Sincronizamos a cópia protegida antes de apagar a sessão local.
    try {
      await _biometricLogin.refreshCurrentSessionIfEnabled();
    } catch (_) {
      // A senha continua sendo alternativa segura se o cofre local falhar.
    }
    return _repository.signOutLocally();
  }
}
