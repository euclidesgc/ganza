import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/bank_connection_repository.dart';

class StartBankConnection {
  const StartBankConnection(this._repository);

  final BankConnectionRepository _repository;

  Future<Either<Failure, String>> call() {
    return _repository.startConnection();
  }
}
