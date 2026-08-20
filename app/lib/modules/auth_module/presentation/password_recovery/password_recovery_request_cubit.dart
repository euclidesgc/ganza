import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/reset_password_for_email.dart';

part 'password_recovery_request_state.dart';

class PasswordRecoveryRequestCubit extends Cubit<PasswordRecoveryRequestState> {
  PasswordRecoveryRequestCubit(this._resetPasswordForEmail)
    : super(const PasswordRecoveryRequestInitial());

  final ResetPasswordForEmail _resetPasswordForEmail;

  Future<void> submit({required String email}) async {
    emit(const PasswordRecoveryRequestSubmitting());

    final result = await _resetPasswordForEmail(email: email);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => PasswordRecoveryRequestFailed(failure),
        (_) => PasswordRecoveryRequestSent(email.trim()),
      ),
    );
  }
}
