import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/session/session.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/entities/biometric_login_status.dart';
import '../../domain/repositories/biometric_login_service.dart';
import '../../domain/usecases/sign_in.dart';

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._signIn, this._lastSignedInEmail, this._biometricLogin)
    : super(const LoginInitial());

  final SignIn _signIn;
  final LastSignedInEmail _lastSignedInEmail;
  final BiometricLoginService _biometricLogin;

  String? get lastSignedInEmail => _lastSignedInEmail.read();

  Future<BiometricLoginStatus> biometricLoginStatus() =>
      _biometricLogin.status();

  Future<void> disableBiometricLogin() => _biometricLogin.disable();

  Future<void> signIn({
    required String email,
    required String password,
    bool enableBiometrics = false,
  }) async {
    emit(const LoginInProgress());

    final result = await _signIn(email: email, password: password);
    if (isClosed) return;

    final failure = result.getLeft().toNullable();
    if (failure != null) {
      emit(LoginFailed(failure));
      return;
    }

    final user = result.getOrElse((_) => throw StateError('inalcançável'));
    _lastSignedInEmail.save(email);
    try {
      if (enableBiometrics) {
        // A senha acabou de provar a identidade. Guardamos somente o token de
        // renovação no cofre do aparelho para o próximo login biométrico.
        await _biometricLogin.enableForCurrentSession();
      } else {
        // Uma credencial de outra conta não pode sobreviver ao login por senha
        // atual. A nova conta só passa a ter biometria se houver opt-in.
        await _biometricLogin.discardIfNotForCurrentSession();
      }
    } catch (_) {
      // Falhar ao gravar ou remover no cofre não pode transformar um login por
      // senha que já deu certo em falha. O botão biométrico não será oferecido
      // quando não houver uma credencial válida na próxima abertura.
    }
    if (isClosed) return;
    emit(LoginSucceeded(user));
  }

  Future<void> signInWithBiometrics() async {
    emit(const LoginInProgress());

    final result = await _biometricLogin.signIn();
    if (isClosed) return;

    emit(
      result.fold((failure) => LoginFailed(failure), (user) {
        _lastSignedInEmail.save(user.email);
        return LoginSucceeded(user);
      }),
    );
  }
}
