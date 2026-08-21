import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/bank_connection.dart';
import '../repositories/bank_connection_repository.dart';

class GetBankConnection {
  const GetBankConnection(this._repository);

  final BankConnectionRepository _repository;

  Future<Either<Failure, BankConnection?>> call() {
    return _repository.getConnection();
  }
}
