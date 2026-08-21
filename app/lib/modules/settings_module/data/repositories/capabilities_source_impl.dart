import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_from_exception.dart';
import '../../../../core/session/capabilities_source.dart';
import '../../../../core/session/user_capabilities.dart';

class CapabilitiesSourceImpl implements CapabilitiesSource {
  const CapabilitiesSourceImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Either<Failure, UserCapabilities>> load() async {
    try {
      final aiRows = await _client
          .from('ai_user_credentials')
          .select('id')
          .eq('is_active', true)
          .limit(1);

      final bankRows = await _client
          .from('bank_connections')
          .select('id')
          .neq('status', 'disconnected')
          .limit(1);

      return Right(
        UserCapabilities(
          aiConfigured: aiRows.isNotEmpty,
          bankConnected: bankRows.isNotEmpty,
        ),
      );
    } catch (error) {
      return Left(failureFromException(error));
    }
  }
}
