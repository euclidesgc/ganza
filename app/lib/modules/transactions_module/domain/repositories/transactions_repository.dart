import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/transaction.dart';

abstract interface class TransactionsRepository {
  Future<Either<Failure, List<Transaction>>> list();
}
