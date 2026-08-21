import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/bank_connection.dart';
import '../../domain/entities/bank_connection_status.dart';
import '../../domain/usecases/disconnect_bank_connection.dart';
import '../../domain/usecases/get_bank_connection.dart';
import '../../domain/usecases/start_bank_connection.dart';

part 'bank_settings_state.dart';

class BankSettingsCubit extends Cubit<BankSettingsState> {
  BankSettingsCubit(
    this._getConnection,
    this._startConnection,
    this._disconnectConnection,
  ) : super(const BankSettingsLoading());

  final GetBankConnection _getConnection;
  final StartBankConnection _startConnection;
  final DisconnectBankConnection _disconnectConnection;

  Future<void> load() async {
    emit(const BankSettingsLoading());

    final result = await _getConnection();
    if (isClosed) return;

    emit(result.fold(BankSettingsLoadFailed.new, BankSettingsReady.new));
  }

  Future<void> connect() async {
    final connection = state.connectionOrNull;
    emit(BankSettingsConnecting(connection));

    final result = await _startConnection();
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => BankSettingsActionFailed(connection, failure),
        (_) => BankSettingsReady(connection),
      ),
    );
  }

  Future<void> disconnect() async {
    final connection = state.connectionOrNull;
    emit(BankSettingsDisconnecting(connection));

    final result = await _disconnectConnection();
    if (isClosed) return;

    final failure = result.fold((failure) => failure, (_) => null);
    if (failure != null) {
      emit(BankSettingsActionFailed(connection, failure));
      return;
    }

    await load();
  }
}
