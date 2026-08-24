import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/transactions_module/domain/entities/new_transaction.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction_direction.dart';
import 'package:ganza/modules/transactions_module/domain/repositories/transactions_repository.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/create_transaction.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionsRepository extends Mock
    implements TransactionsRepository {}

void main() {
  late MockTransactionsRepository repository;
  late CreateTransaction useCase;

  final newTransaction = NewTransaction(
    direction: TransactionDirection.outgoing,
    amount: 4500,
    description: 'Almoço',
    occurredAt: DateTime(2026, 8, 15),
  );

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
    useCase = CreateTransaction(repository);
  });

  test('devolve Right no sucesso, delegando ao repositório', () async {
    when(
      () => repository.create(newTransaction),
    ).thenAnswer((_) async => Right(transaction));

    final result = await useCase(newTransaction);

    result.fold(
      (failure) => fail('esperava Right, veio $failure'),
      (value) => expect(value, transaction),
    );
    verify(() => repository.create(newTransaction)).called(1);
  });

  test('propaga o Left do repositório na falha', () async {
    const failure = NetworkFailure();
    when(
      () => repository.create(newTransaction),
    ).thenAnswer((_) async => const Left(failure));

    final result = await useCase(newTransaction);

    result.fold(
      (value) => expect(value, failure),
      (_) => fail('esperava Left'),
    );
  });
}
