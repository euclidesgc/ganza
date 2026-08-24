import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/transactions_repository.dart';

class CategorizeTransaction {
  const CategorizeTransaction(this._repository);

  final TransactionsRepository _repository;

  Future<Either<Failure, Unit>> call(String transactionId, String categoryId) =>
      _repository.categorize(transactionId, categoryId);
}
