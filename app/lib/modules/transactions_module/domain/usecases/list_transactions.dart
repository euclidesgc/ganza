import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/transaction.dart';
import '../repositories/transactions_repository.dart';

class ListTransactions {
  const ListTransactions(this._repository);

  final TransactionsRepository _repository;

  Future<Either<Failure, List<Transaction>>> call() => _repository.list();
}
