import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/session/session.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/usecases/sign_in.dart';

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._signIn, this._lastSignedInEmail)
    : super(const LoginInitial());

  final SignIn _signIn;
  final LastSignedInEmail _lastSignedInEmail;

  String? get lastSignedInEmail => _lastSignedInEmail.read();

  Future<void> signIn({required String email, required String password}) async {
    emit(const LoginInProgress());

    final result = await _signIn(email: email, password: password);
    if (isClosed) return;

    emit(
      result.fold((failure) => LoginFailed(failure), (user) {
        _lastSignedInEmail.save(email);
        return LoginSucceeded(user);
      }),
    );
  }
}
