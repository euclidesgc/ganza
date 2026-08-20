part of 'sign_up_cubit.dart';

sealed class SignUpState extends Equatable {
  const SignUpState();

  @override
  List<Object?> get props => [];
}

final class SignUpInitial extends SignUpState {
  const SignUpInitial();
}

final class SignUpInProgress extends SignUpState {
  const SignUpInProgress();
}

final class SignUpSucceeded extends SignUpState {
  const SignUpSucceeded(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

final class SignUpFailed extends SignUpState {
  const SignUpFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
