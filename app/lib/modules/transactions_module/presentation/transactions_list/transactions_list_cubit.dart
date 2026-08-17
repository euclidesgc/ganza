import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/list_transactions.dart';

part 'transactions_list_state.dart';

class TransactionsListCubit extends Cubit<TransactionsListState> {
  TransactionsListCubit(this._listTransactions)
    : super(const TransactionsListLoading());

  final ListTransactions _listTransactions;

  Future<void> load() async {
    emit(const TransactionsListLoading());

    final result = await _listTransactions();
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => TransactionsListLoadFailed(failure),
        (transactions) => transactions.isEmpty
            ? const TransactionsListEmpty()
            : TransactionsListLoaded(transactions),
      ),
    );
  }
}
