part of 'password_recovery_code_cubit.dart';

sealed class PasswordRecoveryCodeState extends Equatable {
  const PasswordRecoveryCodeState();

  @override
  List<Object?> get props => [];
}

final class PasswordRecoveryCodeAwaitingCode extends PasswordRecoveryCodeState {
  const PasswordRecoveryCodeAwaitingCode();
}

final class PasswordRecoveryCodeVerifying extends PasswordRecoveryCodeState {
  const PasswordRecoveryCodeVerifying();
}

final class PasswordRecoveryCodeVerifyFailed extends PasswordRecoveryCodeState {
  const PasswordRecoveryCodeVerifyFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class PasswordRecoveryCodeAwaitingPassword
    extends PasswordRecoveryCodeState {
  const PasswordRecoveryCodeAwaitingPassword();
}

final class PasswordRecoveryCodeUpdating extends PasswordRecoveryCodeState {
  const PasswordRecoveryCodeUpdating();
}

final class PasswordRecoveryCodeUpdateFailed extends PasswordRecoveryCodeState {
  const PasswordRecoveryCodeUpdateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class PasswordRecoveryCodeCompleted extends PasswordRecoveryCodeState {
  const PasswordRecoveryCodeCompleted();
}
