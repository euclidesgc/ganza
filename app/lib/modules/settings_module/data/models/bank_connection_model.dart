import 'package:fpdart/fpdart.dart';
import 'package:zard/zard.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/bank_connection.dart';
import '../../domain/entities/bank_connection_status.dart';

/// Mesmo problema documentado em `ProfileModel`: o `.nullable()` do zard
/// 0.0.26 só seta uma flag — `Schema.parse()` ignora essa flag e lança em
/// qualquer valor `null` antes de rodar validador ou transform. Como
/// `last_synced_at` chega `null` do PostgREST enquanto a conexão nunca
/// sincronizou, o schema precisa interceptar o `null` antes de delegar ao
/// `ZString` interno.
class _NullableString extends Schema<String?> {
  _NullableString(this._inner) {
    nullish();
  }

  final ZString _inner;

  @override
  String? parse(dynamic value, {String path = ''}) {
    if (value == null) return null;
    return _inner.parse(value, path: path);
  }
}

abstract final class BankConnectionModel {
  static final _schema = z.map({
    'id': z.string(),
    'institution_name': z.string(),
    'status': z.$enum(['pending', 'connected', 'error', 'disconnected']),
    'last_synced_at': _NullableString(z.string()),
  });

  static final _accessTokenSchema = z.map({'access_token': z.string()});

  static Either<Failure, BankConnection> fromMap(Map<String, dynamic> map) {
    final result = _schema.safeParse(map);
    if (!result.success || result.data == null) {
      return const Left(
        ValidationFailure('Conexão bancária em formato inesperado.'),
      );
    }

    final data = result.data!;
    final lastSyncedAtRaw = data['last_synced_at'] as String?;
    DateTime? lastSyncedAt;
    if (lastSyncedAtRaw != null) {
      lastSyncedAt = DateTime.tryParse(lastSyncedAtRaw);
      if (lastSyncedAt == null) {
        return const Left(
          ValidationFailure('Conexão bancária em formato inesperado.'),
        );
      }
    }

    return Right(
      BankConnection(
        id: data['id'] as String,
        institution: data['institution_name'] as String,
        // O `z.$enum` acima já restringe `status` aos quatro valores da
        // check constraint de `bank_connections` — chegando aqui, o valor é
        // sempre um nome válido de `BankConnectionStatus`.
        status: BankConnectionStatus.values.byName(data['status'] as String),
        lastSyncedAt: lastSyncedAt?.toUtc(),
      ),
    );
  }

  /// Resposta da Edge Function `bank-connections` para `connect_token`.
  static Either<Failure, String> accessTokenFromMap(Map<String, dynamic> map) {
    final result = _accessTokenSchema.safeParse(map);
    if (!result.success || result.data == null) {
      return const Left(
        ValidationFailure(
          'Resposta de conexão bancária em formato inesperado.',
        ),
      );
    }
    return Right(result.data!['access_token'] as String);
  }
}
