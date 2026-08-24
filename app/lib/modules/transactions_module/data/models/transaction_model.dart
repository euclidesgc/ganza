import 'package:fpdart/fpdart.dart';
import 'package:zard/zard.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/new_transaction.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_direction.dart';

/// A resposta do PostgREST muda quando a migration muda. Validar aqui é o
/// que impede uma coluna renomeada, um `amount` que chegasse como texto ou
/// um `direction` fora do enum fechado de virar erro em runtime três telas
/// adiante.
abstract final class TransactionModel {
  static final _schema = z.map({
    'id': z.string(),
    'area_id': z.string().optional(),
    'direction': z.string(),
    'amount': z.int(),
    'description': z.string(),
    'occurred_at': z.string(),
    'source': z.string(),
    'reconciliation_status': z.string(),
    'created_at': z.string(),
    'updated_at': z.string(),
    'category_id': z.string().optional(),
  });

  static final _categorySchema = z.map({'name': z.string()});

  static Either<Failure, Transaction> fromMap(Map<String, dynamic> map) {
    final result = _schema.safeParse(_withoutNulls(map));
    if (!result.success || result.data == null) {
      return const Left(ValidationFailure('Transação em formato inesperado.'));
    }

    final data = result.data!;

    final direction = _directionFromWire(data['direction'] as String);
    final occurredAt = DateTime.tryParse(data['occurred_at'] as String);
    final createdAt = DateTime.tryParse(data['created_at'] as String);
    final updatedAt = DateTime.tryParse(data['updated_at'] as String);
    if (direction == null ||
        occurredAt == null ||
        createdAt == null ||
        updatedAt == null) {
      return const Left(ValidationFailure('Transação em formato inesperado.'));
    }

    return Right(
      Transaction(
        id: data['id'] as String,
        areaId: data['area_id'] as String?,
        direction: direction,
        amount: data['amount'] as int,
        description: data['description'] as String,
        occurredAt: occurredAt.toUtc(),
        source: data['source'] as String,
        reconciliationStatus: data['reconciliation_status'] as String,
        createdAt: createdAt.toUtc(),
        updatedAt: updatedAt.toUtc(),
        categoryId: data['category_id'] as String?,
        categoryName: _categoryName(map['categories']),
      ),
    );
  }

  /// `user_id` fica de fora porque quem decide o dono é o `auth.uid()` no
  /// banco; `area_id` fica de fora pela decisão D13. Mandá-los seria
  /// inofensivo hoje, mas o contrato do app não deve sugerir que eles existem.
  static Map<String, dynamic> toPayload(NewTransaction transaction) {
    return {
      'direction': transaction.direction.wireValue,
      'amount': transaction.amount,
      'description': transaction.description,
      'occurred_at': transaction.occurredAt.toUtc().toIso8601String(),
    };
  }

  static TransactionDirection? _directionFromWire(String wireValue) {
    for (final direction in TransactionDirection.values) {
      if (direction.wireValue == wireValue) return direction;
    }
    return null;
  }

  static String? _categoryName(dynamic raw) {
    if (raw is! Map) return null;
    final result = _categorySchema.safeParse(Map<String, dynamic>.from(raw));
    if (!result.success || result.data == null) return null;
    return result.data!['name'] as String;
  }

  /// O `.nullable()` do zard 0.0.26 não aceita `null` de fato — só `.optional()`
  /// (chave ausente) passa. E o PostgREST manda `area_id` nulo explicitamente.
  static Map<String, dynamic> _withoutNulls(Map<String, dynamic> map) => {
    for (final entry in map.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}
