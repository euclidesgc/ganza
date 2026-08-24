import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/categorize_transaction.dart';
import '../../domain/usecases/list_categories.dart';
import '../../domain/usecases/list_transactions.dart';

part 'transactions_list_state.dart';

class TransactionsListCubit extends Cubit<TransactionsListState> {
  TransactionsListCubit(
    this._listTransactions,
    this._listCategories,
    this._categorizeTransaction,
  ) : super(const TransactionsListLoading());

  final ListTransactions _listTransactions;
  final ListCategories _listCategories;
  final CategorizeTransaction _categorizeTransaction;

  Future<void> load() async {
    emit(const TransactionsListLoading());

    final transactions = await _listTransactions();
    final categories = await _listCategories();
    if (isClosed) return;

    if (transactions.isLeft()) {
      emit(TransactionsListLoadFailed(transactions.getLeft().toNullable()!));
      return;
    }
    if (categories.isLeft()) {
      emit(TransactionsListLoadFailed(categories.getLeft().toNullable()!));
      return;
    }

    final list = transactions.getOrElse((_) => const <Transaction>[]);
    emit(
      list.isEmpty
          ? const TransactionsListEmpty()
          : TransactionsListLoaded(
              list,
              categories: categories.getOrElse((_) => const <Category>[]),
            ),
    );
  }

  Future<void> categorize(String transactionId, String categoryId) async {
    final result = await _categorizeTransaction(transactionId, categoryId);
    if (isClosed || result.isLeft()) return;

    await load();
  }
}
