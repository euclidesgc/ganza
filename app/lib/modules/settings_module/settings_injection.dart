import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/session/capabilities_source.dart';
import 'data/repositories/ai_credential_repository_impl.dart';
import 'data/repositories/capabilities_source_impl.dart';
import 'data/repositories/profile_repository_impl.dart';
import 'domain/repositories/ai_credential_repository.dart';
import 'domain/repositories/profile_repository.dart';
import 'domain/usecases/delete_ai_credential.dart';
import 'domain/usecases/get_ai_credential.dart';
import 'domain/usecases/get_ai_provider_kinds.dart';
import 'domain/usecases/get_user_profile.dart';
import 'domain/usecases/save_ai_credential.dart';
import 'domain/usecases/update_display_name.dart';
import 'presentation/account/account_cubit.dart';
import 'presentation/ai/ai_settings_cubit.dart';

void registerSettingsModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<AiCredentialRepository>(
      () => AiCredentialRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<CapabilitiesSource>(
      () => CapabilitiesSourceImpl(getIt<SupabaseClient>()),
    )
    ..registerFactory(() => GetUserProfile(getIt<ProfileRepository>()))
    ..registerFactory(() => UpdateDisplayName(getIt<ProfileRepository>()))
    ..registerFactory(
      () => AccountCubit(getIt<GetUserProfile>(), getIt<UpdateDisplayName>()),
    )
    ..registerFactory(() => GetAiProviderKinds(getIt<AiCredentialRepository>()))
    ..registerFactory(() => GetAiCredential(getIt<AiCredentialRepository>()))
    ..registerFactory(() => SaveAiCredential(getIt<AiCredentialRepository>()))
    ..registerFactory(() => DeleteAiCredential(getIt<AiCredentialRepository>()))
    ..registerFactory(
      () => AiSettingsCubit(
        getIt<GetAiProviderKinds>(),
        getIt<GetAiCredential>(),
        getIt<SaveAiCredential>(),
      ),
    );
}
