part of 'login_cubit.dart';

sealed class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object?> get props => [];
}

final class LoginInitial extends LoginState {
  const LoginInitial();
}

final class LoginInProgress extends LoginState {
  const LoginInProgress();
}

final class LoginSucceeded extends LoginState {
  const LoginSucceeded(this.user);

  final AuthenticatedUser user;

  @override
  List<Object?> get props => [user];
}

final class LoginFailed extends LoginState {
  const LoginFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
