import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repositories/areas_repository_impl.dart';
import 'domain/repositories/areas_repository.dart';
import 'domain/usecases/list_active_areas.dart';
import 'presentation/areas/areas_cubit.dart';

void registerAreasModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<AreasRepository>(
      () => AreasRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerFactory(() => ListActiveAreas(getIt<AreasRepository>()))
    ..registerFactory(() => AreasCubit(getIt<ListActiveAreas>()));
}
