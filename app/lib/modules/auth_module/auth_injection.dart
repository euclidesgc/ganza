import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/get_current_user.dart';
import 'domain/usecases/observe_current_user.dart';
import 'domain/usecases/sign_in.dart';
import 'domain/usecases/sign_out.dart';
import 'presentation/login/login_cubit.dart';

void registerAuthModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerFactory(() => SignIn(getIt<AuthRepository>()))
    ..registerFactory(() => SignOut(getIt<AuthRepository>()))
    ..registerFactory(() => ObserveCurrentUser(getIt<AuthRepository>()))
    ..registerFactory(() => GetCurrentUser(getIt<AuthRepository>()))
    ..registerFactory(() => LoginCubit(getIt<SignIn>()));
}
