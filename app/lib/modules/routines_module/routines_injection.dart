import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repositories/routines_repository_impl.dart';
import 'domain/repositories/routines_repository.dart';
import 'domain/usecases/list_pending_occurrences.dart';
import 'domain/usecases/list_routine_summaries.dart';
import 'domain/usecases/resolve_occurrence.dart';
import 'presentation/routines/routines_cubit.dart';

void registerRoutinesModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<RoutinesRepository>(
      () => RoutinesRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerFactory(() => ListPendingOccurrences(getIt<RoutinesRepository>()))
    ..registerFactory(() => ListRoutineSummaries(getIt<RoutinesRepository>()))
    ..registerFactory(() => ResolveOccurrence(getIt<RoutinesRepository>()))
    ..registerFactory(
      () => RoutinesCubit(
        getIt<ListPendingOccurrences>(),
        getIt<ListRoutineSummaries>(),
        getIt<ResolveOccurrence>(),
      ),
    );
}
