import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/transactions_module/domain/entities/new_transaction.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction_direction.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/create_transaction.dart';
import 'package:ganza/modules/transactions_module/presentation/new_transaction/new_transaction_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateTransaction extends Mock implements CreateTransaction {}

void main() {
  late MockCreateTransaction createTransaction;

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
    createTransaction = MockCreateTransaction();
  });

  blocTest<NewTransactionCubit, NewTransactionState>(
    'emite Submitting e Succeeded no envio com sucesso',
    build: () => NewTransactionCubit(createTransaction),
    act: (cubit) async {
      when(
        () => createTransaction.call(newTransaction),
      ).thenAnswer((_) async => Right(transaction));
      await cubit.submit(newTransaction);
    },
    expect: () => [
      const NewTransactionSubmitting(),
      NewTransactionSucceeded(transaction),
    ],
  );

  blocTest<NewTransactionCubit, NewTransactionState>(
    'emite Submitting e Failed no envio com falha',
    build: () => NewTransactionCubit(createTransaction),
    act: (cubit) async {
      when(
        () => createTransaction.call(newTransaction),
      ).thenAnswer((_) async => const Left(NetworkFailure()));
      await cubit.submit(newTransaction);
    },
    expect: () => [
      const NewTransactionSubmitting(),
      const NewTransactionFailed(NetworkFailure()),
    ],
  );
}
