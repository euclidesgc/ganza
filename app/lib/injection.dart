import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/network/dio_factory.dart';
import 'core/session/session.dart';
import 'modules/areas_module/areas_module.dart';
import 'modules/auth_module/auth_module.dart';
import 'modules/chat_module/chat_module.dart';
import 'modules/commitments_module/commitments_module.dart';
import 'modules/routines_module/routines_module.dart';
import 'modules/settings_module/settings_module.dart';
import 'modules/transactions_module/transactions_module.dart';

final getIt = GetIt.instance;

void registerDependencies(AppConfig config) {
  getIt
    ..registerSingleton<AppConfig>(config)
    ..registerLazySingleton<SupabaseClient>(() => Supabase.instance.client)
    ..registerLazySingleton<Dio>(
      () => createDio(
        config,
        accessToken: () =>
            getIt<SupabaseClient>().auth.currentSession?.accessToken ?? '',
      ),
    )
    ..registerLazySingleton<PasswordRecoveryScope>(PasswordRecoveryScope.new)
    ..registerLazySingleton<LastSignedInEmail>(LastSignedInEmail.new)
    ..registerLazySingleton<CapabilitiesCubit>(
      () => CapabilitiesCubit(getIt<CapabilitiesSource>()),
    );

  registerAuthModule(getIt);
  registerAreasModule(getIt);
  registerChatModule(getIt);
  registerCommitmentsModule(getIt);
  registerRoutinesModule(getIt);
  registerSettingsModule(getIt);
  registerTransactionsModule(getIt);
}
