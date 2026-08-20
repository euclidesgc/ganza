import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/session/session.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/update_password.dart';
import '../../domain/usecases/verify_recovery_code.dart';

part 'password_recovery_code_state.dart';

class PasswordRecoveryCodeCubit extends Cubit<PasswordRecoveryCodeState> {
  PasswordRecoveryCodeCubit(
    this._verifyRecoveryCode,
    this._updatePassword,
    this._signOut,
    this._recoveryScope,
  ) : super(const PasswordRecoveryCodeAwaitingCode()) {
    // PasswordRecoveryScope liga assim que esta tela nasce: o verifyOTP a
    // seguir autentica a sessão, e sem o escopo a guarda de rota trataria
    // isso como login normal e mandaria o usuário para a raiz antes de ele
    // ver o campo de nova senha.
    _recoveryScope.begin();
  }

  final VerifyRecoveryCode _verifyRecoveryCode;
  final UpdatePassword _updatePassword;
  final SignOut _signOut;
  final PasswordRecoveryScope _recoveryScope;

  // Só existe botão de cancelar na etapa do código: antes do verifyOTP
  // confirmar, a sessão de recuperação ainda não é a que protege a troca de
  // senha, então desligar aqui devolve o usuário ao login sem abrir brecha
  // na guarda de rota nem tocar no estado que a etapa seguinte protege.
  void cancel() {
    _recoveryScope.end();
  }

  Future<void> verifyCode({required String email, required String code}) async {
    emit(const PasswordRecoveryCodeVerifying());

    final result = await _verifyRecoveryCode(email: email, token: code);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => PasswordRecoveryCodeVerifyFailed(failure),
        (_) => const PasswordRecoveryCodeAwaitingPassword(),
      ),
    );
  }

  Future<void> submitNewPassword({required String newPassword}) async {
    emit(const PasswordRecoveryCodeUpdating());

    final result = await _updatePassword(newPassword: newPassword);
    if (isClosed) return;

    result.fold((failure) => emit(PasswordRecoveryCodeUpdateFailed(failure)), (
      _,
    ) {
      // PasswordRecoveryScope desliga só aqui, depois da senha trocada: é
      // o sinal que devolve à guarda de rota o caminho normal de sessão
      // válida — sem ele o usuário ficaria preso nesta tela para sempre.
      _recoveryScope.end();
      emit(const PasswordRecoveryCodeCompleted());
    });
  }

  // Sair encerra a sessão do GoTrue antes de desligar o escopo: se o escopo
  // caísse primeiro com a sessão ainda válida, a guarda de rota leria
  // "login normal" e devolveria o usuário para dentro do app, abrindo um
  // caminho discreto de sessão persistente a partir do inbox alheio.
  Future<void> signOutWithoutChangingPassword() async {
    await _signOut();
    _recoveryScope.end();
  }
}
