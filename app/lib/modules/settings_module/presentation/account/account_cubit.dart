import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/get_user_profile.dart';
import '../../domain/usecases/update_display_name.dart';

part 'account_state.dart';

class AccountCubit extends Cubit<AccountState> {
  AccountCubit(this._getUserProfile, this._updateDisplayName)
    : super(const AccountLoading());

  final GetUserProfile _getUserProfile;
  final UpdateDisplayName _updateDisplayName;

  Future<void> load() async {
    emit(const AccountLoading());

    final result = await _getUserProfile();
    if (isClosed) return;

    emit(result.fold(AccountLoadFailed.new, AccountReady.new));
  }

  Future<void> save({required String displayName}) async {
    final profile = state.profileOrNull;
    if (profile == null) return;

    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      emit(
        AccountSaveFailed(
          profile,
          const ValidationFailure('Informe um nome de exibição.'),
        ),
      );
      return;
    }

    emit(AccountSaving(profile));

    final result = await _updateDisplayName(displayName: trimmed);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => AccountSaveFailed(profile, failure),
        AccountReady.new,
      ),
    );
  }
}
