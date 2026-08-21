import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_from_exception.dart';
import '../../domain/entities/bank_connection.dart';
import '../../domain/repositories/bank_connection_repository.dart';
import '../models/bank_connection_model.dart';

class BankConnectionRepositoryImpl implements BankConnectionRepository {
  const BankConnectionRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, institution_name, status, last_synced_at';

  @override
  Future<Either<Failure, BankConnection?>> getConnection() async {
    try {
      final row = await _client
          .from('bank_connections')
          .select(_columns)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return const Right(null);
      return BankConnectionModel.fromMap(row).map<BankConnection?>((c) => c);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  @override
  Future<Either<Failure, String>> startConnection() async {
    try {
      final response = await _client.functions.invoke(
        'bank-connections',
        body: {'action': 'connect_token'},
      );
      return BankConnectionModel.accessTokenFromMap(
        response.data as Map<String, dynamic>,
      );
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  /// O contrato de domínio não recebe um id — resolve a conexão ativa do
  /// próprio usuário (a RLS garante que só a dele aparece) e manda o id para
  /// a Edge Function, que é quem fecha o item no agregador bancário e marca
  /// a linha como `disconnected`. Sem conexão ativa, desconectar é um
  /// no-op — idempotente como o `deleteCredential` de
  /// `AiCredentialRepositoryImpl`.
  @override
  Future<Either<Failure, Unit>> disconnect() async {
    try {
      final row = await _client
          .from('bank_connections')
          .select('id')
          .neq('status', 'disconnected')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return const Right(unit);

      await _client.functions.invoke(
        'bank-connections',
        body: {'action': 'disconnect', 'connection_id': row['id'] as String},
      );
      return const Right(unit);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }
}
