import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_from_exception.dart';
import '../../../../core/session/capabilities_source.dart';
import '../../../../core/session/user_capabilities.dart';

/// Banco conectado fica fixo em `false`: a integração bancária é a Fase 5 e
/// hoje não existe fonte nenhuma para essa capacidade. Um `false` honesto
/// vale mais que um campo que finge saber.
class CapabilitiesSourceImpl implements CapabilitiesSource {
  const CapabilitiesSourceImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Either<Failure, UserCapabilities>> load() async {
    try {
      final rows = await _client
          .from('ai_user_credentials')
          .select('id')
          .eq('is_active', true)
          .limit(1);

      return Right(
        UserCapabilities(aiConfigured: rows.isNotEmpty, bankConnected: false),
      );
    } catch (error) {
      return Left(failureFromException(error));
    }
  }
}
