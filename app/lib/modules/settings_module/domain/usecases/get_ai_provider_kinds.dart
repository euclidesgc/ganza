import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/ai_provider_kind.dart';
import '../repositories/ai_credential_repository.dart';

class GetAiProviderKinds {
  const GetAiProviderKinds(this._repository);

  final AiCredentialRepository _repository;

  Future<Either<Failure, List<AiProviderKind>>> call() {
    return _repository.getProviderKinds();
  }
}
