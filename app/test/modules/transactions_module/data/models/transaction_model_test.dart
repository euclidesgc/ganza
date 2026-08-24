import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/transactions_module/data/models/transaction_model.dart';
import 'package:ganza/modules/transactions_module/domain/entities/new_transaction.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction_direction.dart';

void main() {
  final validMap = <String, dynamic>{
    'id': 't1',
    'area_id': null,
    'direction': 'out',
    'amount': 4500,
    'description': 'Almoço',
    'occurred_at': '2026-08-15T00:00:00.000Z',
    'source': 'manual',
    'reconciliation_status': 'pending',
    'created_at': '2026-08-15T00:00:00.000Z',
    'updated_at': '2026-08-15T00:00:00.000Z',
  };

  group('TransactionModel.fromMap', () {
    test('payload válido devolve Right com todos os campos', () {
      final result = TransactionModel.fromMap(validMap);
      result.fold((failure) => fail('esperava Right, veio $failure'), (
        transaction,
      ) {
        expect(transaction.id, 't1');
        expect(transaction.areaId, isNull);
        expect(transaction.direction, TransactionDirection.outgoing);
        expect(transaction.amount, 4500);
        expect(transaction.description, 'Almoço');
      });
    });

    test('amount como string devolve Left(ValidationFailure)', () {
      final result = TransactionModel.fromMap({...validMap, 'amount': '4500'});
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('direction desconhecida devolve Left(ValidationFailure)', () {
      final result = TransactionModel.fromMap({...validMap, 'direction': 'x'});
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('area_id nulo é aceito e vira null na entidade', () {
      final result = TransactionModel.fromMap(validMap);
      result.fold(
        (failure) => fail('esperava Right, veio $failure'),
        (transaction) => expect(transaction.areaId, isNull),
      );
    });
  });

  group('TransactionModel.toPayload', () {
    test('devolve exatamente as quatro chaves, sem user_id nem area_id', () {
      final newTransaction = NewTransaction(
        direction: TransactionDirection.outgoing,
        amount: 4500,
        description: 'Almoço',
        occurredAt: DateTime(2026, 8, 15),
      );

      final payload = TransactionModel.toPayload(newTransaction);

      expect(payload.keys.toSet(), {
        'direction',
        'amount',
        'description',
        'occurred_at',
      });
      expect(payload['direction'], 'out');
      expect(payload['amount'], 4500);
    });
  });
}
