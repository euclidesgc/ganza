import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repositories/categories_repository_impl.dart';
import 'data/repositories/transactions_repository_impl.dart';
import 'domain/repositories/categories_repository.dart';
import 'domain/repositories/transactions_repository.dart';
import 'domain/usecases/categorize_transaction.dart';
import 'domain/usecases/create_transaction.dart';
import 'domain/usecases/list_categories.dart';
import 'domain/usecases/list_transactions.dart';
import 'presentation/new_transaction/new_transaction_cubit.dart';
import 'presentation/transactions_list/transactions_list_cubit.dart';

void registerTransactionsModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<TransactionsRepository>(
      () => TransactionsRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<CategoriesRepository>(
      () => CategoriesRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerFactory(() => ListTransactions(getIt<TransactionsRepository>()))
    ..registerFactory(() => CreateTransaction(getIt<TransactionsRepository>()))
    ..registerFactory(
      () => CategorizeTransaction(getIt<TransactionsRepository>()),
    )
    ..registerFactory(() => ListCategories(getIt<CategoriesRepository>()))
    ..registerFactory(
      () => TransactionsListCubit(
        getIt<ListTransactions>(),
        getIt<ListCategories>(),
        getIt<CategorizeTransaction>(),
      ),
    )
    ..registerFactory(() => NewTransactionCubit(getIt<CreateTransaction>()));
}
