import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/change_password.dart';

part 'change_password_state.dart';

class ChangePasswordCubit extends Cubit<ChangePasswordState> {
  ChangePasswordCubit(this._changePassword)
    : super(const ChangePasswordInitial());

  final ChangePassword _changePassword;

  Future<void> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    emit(const ChangePasswordInProgress());

    final result = await _changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    if (isClosed) return;

    emit(
      result.fold(
        ChangePasswordFailed.new,
        (_) => const ChangePasswordSucceeded(),
      ),
    );
  }
}
