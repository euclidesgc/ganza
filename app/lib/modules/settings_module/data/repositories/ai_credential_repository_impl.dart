import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_from_exception.dart';
import '../../domain/entities/ai_credential.dart';
import '../../domain/entities/ai_provider_kind.dart';
import '../../domain/repositories/ai_credential_repository.dart';
import '../models/ai_credential_model.dart';
import '../models/ai_provider_kind_model.dart';

class AiCredentialRepositoryImpl implements AiCredentialRepository {
  const AiCredentialRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _credentialColumns =
      'id, provider_kind_id, model, key_last4, is_active';

  @override
  Future<Either<Failure, List<AiProviderKind>>> getProviderKinds() async {
    try {
      final rows = await _client
          .from('ai_provider_kinds')
          .select('id, slug, name')
          .order('name');

      final kinds = <AiProviderKind>[];
      for (final row in rows) {
        final parsed = AiProviderKindModel.fromMap(row);
        if (parsed.isLeft()) {
          return parsed.map((kind) => <AiProviderKind>[kind]);
        }
        kinds.add(parsed.getOrElse((_) => throw StateError('inalcançável')));
      }
      return Right(kinds);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  /// Sem filtro por `user_id` na query: a RLS de `ai_user_credentials` já
  /// restringe a linha ao dono, e uma credencial só existe ativa aqui
  /// enquanto o produto suportar um único provedor configurado por vez.
  @override
  Future<Either<Failure, AiCredential?>> getCredential() async {
    try {
      final row = await _client
          .from('ai_user_credentials')
          .select(_credentialColumns)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return const Right(null);
      return AiCredentialModel.fromMap(row);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  /// A chave em claro é parâmetro deste método, nunca campo de model: ela
  /// só atravessa como corpo da chamada à Edge Function `ai-credentials`,
  /// que é quem decide onde guardá-la (Vault) — o PostgREST nunca a vê.
  @override
  Future<Either<Failure, AiCredential>> saveCredential({
    required String providerKindId,
    required String model,
    required String apiKey,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'ai-credentials',
        body: {
          'action': 'save',
          'provider_kind_id': providerKindId,
          'model': model,
          'api_key': apiKey,
        },
      );
      return AiCredentialModel.fromSaveResponse(
        response.data as Map<String, dynamic>,
      );
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  /// O contrato de domínio não recebe um id — resolve a credencial ativa do
  /// próprio usuário (a RLS garante que só a dele aparece) e manda o id para
  /// a Edge Function, que é quem apaga a linha e o segredo do Vault junto.
  @override
  Future<Either<Failure, Unit>> deleteCredential() async {
    try {
      final row = await _client
          .from('ai_user_credentials')
          .select('id')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return const Right(unit);

      await _client.functions.invoke(
        'ai-credentials',
        body: {'action': 'delete', 'credential_id': row['id'] as String},
      );
      return const Right(unit);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }
}
