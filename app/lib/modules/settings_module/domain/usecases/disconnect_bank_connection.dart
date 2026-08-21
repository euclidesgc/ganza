import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/bank_connection_repository.dart';

class DisconnectBankConnection {
  const DisconnectBankConnection(this._repository);

  final BankConnectionRepository _repository;

  Future<Either<Failure, Unit>> call() {
    return _repository.disconnect();
  }
}
