import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/ai_credential_repository.dart';

class DeleteAiCredential {
  const DeleteAiCredential(this._repository);

  final AiCredentialRepository _repository;

  Future<Either<Failure, Unit>> call() {
    return _repository.deleteCredential();
  }
}
