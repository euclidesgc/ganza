import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repositories/commitments_repository_impl.dart';
import 'domain/repositories/commitments_repository.dart';
import 'domain/usecases/list_commitments.dart';
import 'domain/usecases/simulate_early_payoff.dart';
import 'presentation/commitments/commitments_cubit.dart';

void registerCommitmentsModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<CommitmentsRepository>(
      () => CommitmentsRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerFactory(() => ListCommitments(getIt<CommitmentsRepository>()))
    ..registerFactory(() => SimulateEarlyPayoff(getIt<CommitmentsRepository>()))
    ..registerFactory(
      () => CommitmentsCubit(
        getIt<ListCommitments>(),
        getIt<SimulateEarlyPayoff>(),
      ),
    );
}
