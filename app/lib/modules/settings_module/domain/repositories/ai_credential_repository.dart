import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/ai_credential.dart';
import '../entities/ai_provider_kind.dart';

abstract interface class AiCredentialRepository {
  Future<Either<Failure, List<AiProviderKind>>> getProviderKinds();

  Future<Either<Failure, AiCredential?>> getCredential();

  Future<Either<Failure, AiCredential>> saveCredential({
    required String providerKindId,
    required String model,
    required String apiKey,
  });

  Future<Either<Failure, Unit>> deleteCredential();
}
