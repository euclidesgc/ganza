import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/ai_credential.dart';
import '../repositories/ai_credential_repository.dart';

class GetAiCredential {
  const GetAiCredential(this._repository);

  final AiCredentialRepository _repository;

  Future<Either<Failure, AiCredential?>> call() {
    return _repository.getCredential();
  }
}
