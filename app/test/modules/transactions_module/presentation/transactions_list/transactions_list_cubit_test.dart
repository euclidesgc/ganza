import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction_direction.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/list_transactions.dart';
import 'package:ganza/modules/transactions_module/presentation/transactions_list/transactions_list_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockListTransactions extends Mock implements ListTransactions {}

void main() {
  late MockListTransactions listTransactions;

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
    listTransactions = MockListTransactions();
  });

  blocTest<TransactionsListCubit, TransactionsListState>(
    'emite Empty quando a lista vem vazia',
    build: () => TransactionsListCubit(listTransactions),
    act: (cubit) async {
      when(
        () => listTransactions.call(),
      ).thenAnswer((_) async => const Right([]));
      await cubit.load();
    },
    expect: () => [
      const TransactionsListLoading(),
      const TransactionsListEmpty(),
    ],
  );

  blocTest<TransactionsListCubit, TransactionsListState>(
    'emite Loaded com os itens da lista',
    build: () => TransactionsListCubit(listTransactions),
    act: (cubit) async {
      when(
        () => listTransactions.call(),
      ).thenAnswer((_) async => Right([transaction]));
      await cubit.load();
    },
    expect: () => [
      const TransactionsListLoading(),
      TransactionsListLoaded([transaction]),
    ],
  );

  blocTest<TransactionsListCubit, TransactionsListState>(
    'emite LoadFailed na falha',
    build: () => TransactionsListCubit(listTransactions),
    act: (cubit) async {
      when(
        () => listTransactions.call(),
      ).thenAnswer((_) async => const Left(NetworkFailure()));
      await cubit.load();
    },
    expect: () => [
      const TransactionsListLoading(),
      const TransactionsListLoadFailed(NetworkFailure()),
    ],
  );
}
