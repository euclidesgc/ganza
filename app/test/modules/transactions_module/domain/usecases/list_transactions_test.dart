import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction_direction.dart';
import 'package:ganza/modules/transactions_module/domain/repositories/transactions_repository.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/list_transactions.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionsRepository extends Mock
    implements TransactionsRepository {}

void main() {
  late MockTransactionsRepository repository;
  late ListTransactions useCase;

  final transaction = Transaction(
    id: 't1',
    areaId: null,
    direction: TransactionDirection.outgoing,
    amount: 4500,
    description: 'Almoço',
    occurredAt: DateTime(2026, 8, 15),
    source: 'manual',
    reconciliationStatus: 'pending',
    createdAt: DateTime(2026, 8, 15),
    updatedAt: DateTime(2026, 8, 15),
  );

  setUp(() {
    repository = MockTransactionsRepository();
    useCase = ListTransactions(repository);
  });

  test('devolve Right com lista vazia', () async {
    when(() => repository.list()).thenAnswer((_) async => const Right([]));

    final result = await useCase();

    result.fold(
      (failure) => fail('esperava Right, veio $failure'),
      (list) => expect(list, isEmpty),
    );
  });

  test('devolve Right com os itens do repositório', () async {
    when(() => repository.list()).thenAnswer((_) async => Right([transaction]));

    final result = await useCase();

    result.fold(
      (failure) => fail('esperava Right, veio $failure'),
      (list) => expect(list, [transaction]),
    );
  });

  test('propaga o Left do repositório na falha', () async {
    const failure = NetworkFailure();
    when(() => repository.list()).thenAnswer((_) async => const Left(failure));

    final result = await useCase();

    result.fold(
      (value) => expect(value, failure),
      (_) => fail('esperava Left'),
    );
  });
}
