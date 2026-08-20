import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/sign_up.dart';

part 'sign_up_state.dart';

class SignUpCubit extends Cubit<SignUpState> {
  SignUpCubit(this._signUp) : super(const SignUpInitial());

  final SignUp _signUp;

  Future<void> signUp({required String email, required String password}) async {
    emit(const SignUpInProgress());

    final result = await _signUp(email: email, password: password);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => SignUpFailed(failure),
        (_) => SignUpSucceeded(email),
      ),
    );
  }
}
