import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/usecases/sign_in.dart';

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._signIn) : super(const LoginInitial());

  final SignIn _signIn;

  Future<void> signIn({required String email, required String password}) async {
    emit(const LoginInProgress());

    final result = await _signIn(email: email, password: password);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => LoginFailed(failure),
        (user) => LoginSucceeded(user),
      ),
    );
  }
}
