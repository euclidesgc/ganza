import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/network/dio_factory.dart';

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
    );
}
