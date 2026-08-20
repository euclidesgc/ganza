part of 'change_password_cubit.dart';

sealed class ChangePasswordState extends Equatable {
  const ChangePasswordState();

  @override
  List<Object?> get props => [];
}

final class ChangePasswordInitial extends ChangePasswordState {
  const ChangePasswordInitial();
}

final class ChangePasswordInProgress extends ChangePasswordState {
  const ChangePasswordInProgress();
}

final class ChangePasswordSucceeded extends ChangePasswordState {
  const ChangePasswordSucceeded();
}

final class ChangePasswordFailed extends ChangePasswordState {
  const ChangePasswordFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
