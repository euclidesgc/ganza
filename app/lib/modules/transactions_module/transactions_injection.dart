import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repositories/transactions_repository_impl.dart';
import 'domain/repositories/transactions_repository.dart';
import 'domain/usecases/list_transactions.dart';
import 'presentation/transactions_list/transactions_list_cubit.dart';

void registerTransactionsModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<TransactionsRepository>(
      () => TransactionsRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerFactory(() => ListTransactions(getIt<TransactionsRepository>()))
    ..registerFactory(() => TransactionsListCubit(getIt<ListTransactions>()));
}
