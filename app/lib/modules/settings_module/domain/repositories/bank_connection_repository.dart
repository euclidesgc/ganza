import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/bank_connection.dart';

abstract interface class BankConnectionRepository {
  Future<Either<Failure, BankConnection?>> getConnection();

  Future<Either<Failure, String>> startConnection();

  Future<Either<Failure, Unit>> disconnect();
}
