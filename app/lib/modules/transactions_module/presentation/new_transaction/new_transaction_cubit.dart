import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/new_transaction.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/create_transaction.dart';

part 'new_transaction_state.dart';

class NewTransactionCubit extends Cubit<NewTransactionState> {
  NewTransactionCubit(this._createTransaction)
    : super(const NewTransactionIdle());

  final CreateTransaction _createTransaction;

  Future<void> submit(NewTransaction transaction) async {
    emit(const NewTransactionSubmitting());

    final result = await _createTransaction(transaction);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => NewTransactionFailed(failure),
        (transaction) => NewTransactionSucceeded(transaction),
      ),
    );
  }
}
