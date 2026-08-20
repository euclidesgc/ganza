part of 'password_recovery_request_cubit.dart';

sealed class PasswordRecoveryRequestState extends Equatable {
  const PasswordRecoveryRequestState();

  @override
  List<Object?> get props => [];
}

final class PasswordRecoveryRequestInitial
    extends PasswordRecoveryRequestState {
  const PasswordRecoveryRequestInitial();
}

final class PasswordRecoveryRequestSubmitting
    extends PasswordRecoveryRequestState {
  const PasswordRecoveryRequestSubmitting();
}

final class PasswordRecoveryRequestSent extends PasswordRecoveryRequestState {
  const PasswordRecoveryRequestSent(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

final class PasswordRecoveryRequestFailed extends PasswordRecoveryRequestState {
  const PasswordRecoveryRequestFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
