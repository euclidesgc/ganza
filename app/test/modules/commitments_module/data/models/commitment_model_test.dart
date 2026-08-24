import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/commitments_module/data/models/commitment_model.dart';
import 'package:ganza/modules/commitments_module/domain/entities/commitment_direction.dart';

void main() {
  final validMap = <String, dynamic>{
    'id': 'c1',
    'name': 'Financiamento do carro',
    'direction': 'out',
    'value_mode': 'installment',
    'total_amount': 6000000,
    'installments_total': 48,
    'interest_rate_monthly': 0.012,
    'amortization_system': 'price',
    'outstanding_balance': 6000000,
  };

  group('CommitmentModel.fromMap', () {
    test('linha completa vira a entidade', () {
      final result = CommitmentModel.fromMap(validMap);
      result.fold((failure) => fail('esperava Right, veio $failure'), (
        commitment,
      ) {
        expect(commitment.id, 'c1');
        expect(commitment.direction, CommitmentDirection.outgoing);
        expect(commitment.totalAmount, 6000000);
        expect(commitment.interestRateMonthly, closeTo(0.012, 0.0001));
        expect(commitment.amortizationSystem, 'price');
      });
    });

    test('sem id devolve Left(ValidationFailure)', () {
      final result = CommitmentModel.fromMap({...validMap}..remove('id'));
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('direction desconhecida devolve Left(ValidationFailure)', () {
      final result = CommitmentModel.fromMap({...validMap, 'direction': 'x'});
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });
}
