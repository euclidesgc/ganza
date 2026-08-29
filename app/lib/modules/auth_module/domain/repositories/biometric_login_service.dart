import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/authenticated_user.dart';
import '../entities/biometric_login_status.dart';

abstract interface class BiometricLoginService {
  Future<BiometricLoginStatus> status();

  /// Guarda apenas o refresh token, cifrado pelo armazenamento seguro nativo.
  /// A senha nunca é persistida pelo app.
  Future<void> enableForCurrentSession();

  /// Atualiza o token salvo somente quando a pessoa já optou pela biometria.
  Future<void> refreshCurrentSessionIfEnabled();

  /// Descarta a credencial se ela tiver sido criada por outra conta.
  ///
  /// Um login por senha não transfere a opção biométrica entre contas no
  /// mesmo aparelho: a nova conta precisa consentir explicitamente.
  Future<void> discardIfNotForCurrentSession();

  Future<void> disable();

  Future<Either<Failure, AuthenticatedUser>> signIn();
}
