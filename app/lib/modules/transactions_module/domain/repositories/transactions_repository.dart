import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/new_transaction.dart';
import '../entities/transaction.dart';

abstract interface class TransactionsRepository {
  Future<Either<Failure, List<Transaction>>> list();

  Future<Either<Failure, Transaction>> create(NewTransaction transaction);
}
