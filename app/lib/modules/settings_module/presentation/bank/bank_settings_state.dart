part of 'bank_settings_cubit.dart';

sealed class BankSettingsState extends Equatable {
  const BankSettingsState();

  @override
  List<Object?> get props => [];
}

extension BankSettingsStateData on BankSettingsState {
  BankConnection? get connectionOrNull => switch (this) {
    BankSettingsReady(:final connection) => connection,
    BankSettingsConnecting(:final connection) => connection,
    BankSettingsDisconnecting(:final connection) => connection,
    BankSettingsActionFailed(:final connection) => connection,
    BankSettingsLoading() || BankSettingsLoadFailed() => null,
  };

  bool get isBusy => switch (this) {
    BankSettingsConnecting() || BankSettingsDisconnecting() => true,
    BankSettingsLoading() ||
    BankSettingsLoadFailed() ||
    BankSettingsReady() ||
    BankSettingsActionFailed() => false,
  };

  BankConnectionStatus get displayStatus =>
      connectionOrNull?.status ?? BankConnectionStatus.disconnected;
}

final class BankSettingsLoading extends BankSettingsState {
  const BankSettingsLoading();
}

final class BankSettingsLoadFailed extends BankSettingsState {
  const BankSettingsLoadFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class BankSettingsReady extends BankSettingsState {
  const BankSettingsReady(this.connection);

  final BankConnection? connection;

  @override
  List<Object?> get props => [connection];
}

final class BankSettingsConnecting extends BankSettingsState {
  const BankSettingsConnecting(this.connection);

  final BankConnection? connection;

  @override
  List<Object?> get props => [connection];
}

final class BankSettingsDisconnecting extends BankSettingsState {
  const BankSettingsDisconnecting(this.connection);

  final BankConnection? connection;

  @override
  List<Object?> get props => [connection];
}

final class BankSettingsActionFailed extends BankSettingsState {
  const BankSettingsActionFailed(this.connection, this.failure);

  final BankConnection? connection;
  final Failure failure;

  @override
  List<Object?> get props => [connection, failure];
}
