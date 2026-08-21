import 'package:fpdart/fpdart.dart';
import 'package:zard/zard.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/ai_credential.dart';

abstract final class AiCredentialModel {
  static final _schema = z.map({
    'id': z.string(),
    'provider_kind_id': z.string(),
    'model': z.string(),
    'key_last4': z.string(),
    'is_active': z.bool(),
  });

  static final _saveResponseSchema = z.map({
    'id': z.string(),
    'provider_kind_id': z.string(),
    'model': z.string(),
    'key_last4': z.string(),
  });

  static Either<Failure, AiCredential> fromMap(Map<String, dynamic> map) {
    final result = _schema.safeParse(map);
    if (!result.success || result.data == null) {
      return const Left(
        ValidationFailure('Credencial de IA em formato inesperado.'),
      );
    }

    final data = result.data!;
    return Right(
      AiCredential(
        id: data['id'] as String,
        providerKindId: data['provider_kind_id'] as String,
        model: data['model'] as String,
        keyLast4: data['key_last4'] as String,
        isActive: data['is_active'] as bool,
      ),
    );
  }

  /// A resposta de `save` da Edge Function não carrega `is_active`: uma
  /// credencial recém-salva nasce sempre ativa (`ai_user_credentials.is_active
  /// default true`, `supabase/migrations/0007`), então o modelo fixa o valor
  /// aqui em vez de fingir que o servidor o enviou.
  static Either<Failure, AiCredential> fromSaveResponse(
    Map<String, dynamic> map,
  ) {
    final result = _saveResponseSchema.safeParse(map);
    if (!result.success || result.data == null) {
      return const Left(
        ValidationFailure('Credencial de IA em formato inesperado.'),
      );
    }

    final data = result.data!;
    return Right(
      AiCredential(
        id: data['id'] as String,
        providerKindId: data['provider_kind_id'] as String,
        model: data['model'] as String,
        keyLast4: data['key_last4'] as String,
        isActive: true,
      ),
    );
  }
}
