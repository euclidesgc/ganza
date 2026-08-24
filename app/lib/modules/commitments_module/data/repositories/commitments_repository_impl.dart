import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_from_exception.dart';
import '../../domain/entities/commitment.dart';
import '../../domain/entities/payoff_simulation.dart';
import '../../domain/repositories/commitments_repository.dart';
import '../models/commitment_model.dart';

class CommitmentsRepositoryImpl implements CommitmentsRepository {
  const CommitmentsRepositoryImpl(this._client);

  final SupabaseClient _client;

  /// Sem filtro por usuário na query: a RLS decide o dono de cada linha.
  @override
  Future<Either<Failure, List<Commitment>>> list() async {
    try {
      final rows = await _client
          .from('commitments')
          .select(
            'id, name, direction, value_mode, total_amount, '
            'installments_total, interest_rate_monthly, amortization_system, '
            'outstanding_balance',
          )
          .order('created_at');

      final commitments = <Commitment>[];
      for (final row in rows) {
        final parsed = CommitmentModel.fromMap(row);
        if (parsed.isLeft()) {
          return parsed.map((commitment) => <Commitment>[commitment]);
        }
        commitments.add(
          parsed.getOrElse((_) => throw StateError('inalcançável')),
        );
      }
      return Right(commitments);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  @override
  Future<Either<Failure, PayoffSimulation>> simulateEarlyPayoff(
    Commitment commitment,
  ) async {
    final totalAmount = commitment.totalAmount;
    final installments = commitment.installmentsTotal;
    if (totalAmount == null || installments == null) {
      return const Left(
        ValidationFailure('Compromisso sem parcelas para simular.'),
      );
    }

    try {
      final response = await _client.functions.invoke(
        'finance-math',
        body: {
          'mode': commitment.amortizationSystem ?? 'price',
          'total_amount': totalAmount,
          'installments_total': installments,
          'interest_rate_monthly': commitment.interestRateMonthly ?? 0,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final schedule = data['schedule'] as List;
      final nominalTotal = schedule.fold<int>(
        0,
        (sum, row) => sum + ((row as Map)['installment'] as int),
      );
      final presentValue = data['early_payoff_present_value'] as int;

      return Right(
        PayoffSimulation(
          presentValue: presentValue,
          nominalTotal: nominalTotal,
        ),
      );
    } catch (error) {
      return Left(failureFromException(error));
    }
  }
}
