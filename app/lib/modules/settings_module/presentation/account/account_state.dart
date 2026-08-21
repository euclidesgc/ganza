part of 'account_cubit.dart';

sealed class AccountState extends Equatable {
  const AccountState();

  @override
  List<Object?> get props => [];
}

extension AccountStateProfile on AccountState {
  UserProfile? get profileOrNull => switch (this) {
    AccountReady(:final profile) => profile,
    AccountSaving(:final profile) => profile,
    AccountSaveFailed(:final profile) => profile,
    AccountLoading() || AccountLoadFailed() => null,
  };
}

final class AccountLoading extends AccountState {
  const AccountLoading();
}

final class AccountLoadFailed extends AccountState {
  const AccountLoadFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class AccountReady extends AccountState {
  const AccountReady(this.profile);

  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}

final class AccountSaving extends AccountState {
  const AccountSaving(this.profile);

  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}

final class AccountSaveFailed extends AccountState {
  const AccountSaveFailed(this.profile, this.failure);

  final UserProfile profile;
  final Failure failure;

  @override
  List<Object?> get props => [profile, failure];
}
