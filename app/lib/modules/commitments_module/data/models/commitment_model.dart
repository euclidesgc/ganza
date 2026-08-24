import 'package:fpdart/fpdart.dart';
import 'package:zard/zard.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/commitment.dart';
import '../../domain/entities/commitment_direction.dart';

abstract final class CommitmentModel {
  static final _schema = z.map({
    'id': z.string(),
    'name': z.string(),
    'direction': z.string(),
    'value_mode': z.string(),
    'total_amount': z.int().optional(),
    'installments_total': z.int().optional(),
    'interest_rate_monthly': z.num().optional(),
    'amortization_system': z.string().optional(),
    'outstanding_balance': z.int().optional(),
  });

  static Either<Failure, Commitment> fromMap(Map<String, dynamic> map) {
    final result = _schema.safeParse(_withoutNulls(map));
    if (!result.success || result.data == null) {
      return const Left(
        ValidationFailure('Compromisso em formato inesperado.'),
      );
    }

    final data = result.data!;
    final direction = CommitmentDirection.fromWire(data['direction'] as String);
    if (direction == null) {
      return const Left(
        ValidationFailure('Compromisso em formato inesperado.'),
      );
    }

    return Right(
      Commitment(
        id: data['id'] as String,
        name: data['name'] as String,
        direction: direction,
        valueMode: data['value_mode'] as String,
        totalAmount: data['total_amount'] as int?,
        installmentsTotal: data['installments_total'] as int?,
        interestRateMonthly: (data['interest_rate_monthly'] as num?)
            ?.toDouble(),
        amortizationSystem: data['amortization_system'] as String?,
        outstandingBalance: data['outstanding_balance'] as int?,
      ),
    );
  }

  static Map<String, dynamic> _withoutNulls(Map<String, dynamic> map) => {
    for (final entry in map.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}
