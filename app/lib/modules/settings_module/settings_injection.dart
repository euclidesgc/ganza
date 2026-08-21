import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repositories/profile_repository_impl.dart';
import 'domain/repositories/profile_repository.dart';
import 'domain/usecases/get_user_profile.dart';
import 'domain/usecases/update_display_name.dart';
import 'presentation/account/account_cubit.dart';

void registerSettingsModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerFactory(() => GetUserProfile(getIt<ProfileRepository>()))
    ..registerFactory(() => UpdateDisplayName(getIt<ProfileRepository>()))
    ..registerFactory(
      () => AccountCubit(getIt<GetUserProfile>(), getIt<UpdateDisplayName>()),
    );
}
