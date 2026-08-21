import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/ai_credential.dart';
import '../repositories/ai_credential_repository.dart';

class SaveAiCredential {
  const SaveAiCredential(this._repository);

  final AiCredentialRepository _repository;

  Future<Either<Failure, AiCredential>> call({
    required String providerKindId,
    required String model,
    required String apiKey,
  }) {
    final trimmedProviderKindId = providerKindId.trim();
    final trimmedModel = model.trim();
    final trimmedApiKey = apiKey.trim();
    if (trimmedProviderKindId.isEmpty ||
        trimmedModel.isEmpty ||
        trimmedApiKey.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Informe provedor, modelo e chave.')),
      );
    }
    return _repository.saveCredential(
      providerKindId: trimmedProviderKindId,
      model: trimmedModel,
      apiKey: trimmedApiKey,
    );
  }
}
