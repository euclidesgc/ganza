import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/new_transaction.dart';
import '../entities/transaction.dart';
import '../repositories/transactions_repository.dart';

class CreateTransaction {
  const CreateTransaction(this._repository);

  final TransactionsRepository _repository;

  Future<Either<Failure, Transaction>> call(NewTransaction transaction) =>
      _repository.create(transaction);
}
