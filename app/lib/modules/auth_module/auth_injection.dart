import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/session/session.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/get_current_user.dart';
import 'domain/usecases/observe_current_user.dart';
import 'domain/usecases/reset_password_for_email.dart';
import 'domain/usecases/sign_in.dart';
import 'domain/usecases/sign_out.dart';
import 'domain/usecases/sign_up.dart';
import 'domain/usecases/update_password.dart';
import 'domain/usecases/verify_recovery_code.dart';
import 'presentation/login/login_cubit.dart';
import 'presentation/password_recovery/password_recovery_code_cubit.dart';
import 'presentation/password_recovery/password_recovery_request_cubit.dart';
import 'presentation/sign_up/sign_up_cubit.dart';

void registerAuthModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerFactory(() => SignIn(getIt<AuthRepository>()))
    ..registerFactory(() => SignOut(getIt<AuthRepository>()))
    ..registerFactory(() => SignUp(getIt<AuthRepository>()))
    ..registerFactory(() => ResetPasswordForEmail(getIt<AuthRepository>()))
    ..registerFactory(() => VerifyRecoveryCode(getIt<AuthRepository>()))
    ..registerFactory(() => UpdatePassword(getIt<AuthRepository>()))
    ..registerFactory(() => ObserveCurrentUser(getIt<AuthRepository>()))
    ..registerFactory(() => GetCurrentUser(getIt<AuthRepository>()))
    ..registerFactory(
      () => LoginCubit(getIt<SignIn>(), getIt<LastSignedInEmail>()),
    )
    ..registerFactory(() => SignUpCubit(getIt<SignUp>()))
    ..registerFactory(
      () => PasswordRecoveryRequestCubit(getIt<ResetPasswordForEmail>()),
    )
    ..registerFactory(
      () => PasswordRecoveryCodeCubit(
        getIt<VerifyRecoveryCode>(),
        getIt<UpdatePassword>(),
        getIt<SignOut>(),
        getIt<PasswordRecoveryScope>(),
      ),
    );
}
