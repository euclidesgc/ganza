import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/transactions_module/domain/entities/category.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction_direction.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/categorize_transaction.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/list_categories.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/list_transactions.dart';
import 'package:ganza/modules/transactions_module/presentation/transactions_list/transactions_list_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockListTransactions extends Mock implements ListTransactions {}

class MockListCategories extends Mock implements ListCategories {}

class MockCategorizeTransaction extends Mock implements CategorizeTransaction {}

void main() {
  late MockListTransactions listTransactions;
  late MockListCategories listCategories;
  late MockCategorizeTransaction categorizeTransaction;

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

  final category = Category(id: 'c1', name: 'Alimentação');

  setUp(() {
    listTransactions = MockListTransactions();
    listCategories = MockListCategories();
    categorizeTransaction = MockCategorizeTransaction();
    when(
      () => listCategories.call(),
    ).thenAnswer((_) async => const Right(<Category>[]));
  });

  TransactionsListCubit buildCubit() => TransactionsListCubit(
    listTransactions,
    listCategories,
    categorizeTransaction,
  );

  blocTest<TransactionsListCubit, TransactionsListState>(
    'emite Empty quando a lista vem vazia',
    build: buildCubit,
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
    'emite Loaded com os itens da lista e as categorias',
    build: buildCubit,
    act: (cubit) async {
      when(
        () => listTransactions.call(),
      ).thenAnswer((_) async => Right([transaction]));
      when(
        () => listCategories.call(),
      ).thenAnswer((_) async => Right([category]));
      await cubit.load();
    },
    expect: () => [
      const TransactionsListLoading(),
      TransactionsListLoaded([transaction], categories: [category]),
    ],
  );

  blocTest<TransactionsListCubit, TransactionsListState>(
    'emite LoadFailed na falha',
    build: buildCubit,
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

  blocTest<TransactionsListCubit, TransactionsListState>(
    'categorize chama o use case e refaz a leitura',
    build: buildCubit,
    act: (cubit) async {
      var calls = 0;
      when(() => listTransactions.call()).thenAnswer((_) async {
        calls += 1;
        return calls == 1
            ? Right([transaction])
            : Right([
                Transaction(
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
                  categoryId: 'c1',
                  categoryName: 'Alimentação',
                ),
              ]);
      });
      when(
        () => categorizeTransaction.call('t1', 'c1'),
      ).thenAnswer((_) async => const Right(unit));
      await cubit.load();
      await cubit.categorize('t1', 'c1');
    },
    verify: (_) {
      verify(() => categorizeTransaction.call('t1', 'c1')).called(1);
    },
    expect: () => [
      const TransactionsListLoading(),
      TransactionsListLoaded([transaction]),
      const TransactionsListLoading(),
      TransactionsListLoaded([
        Transaction(
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
          categoryId: 'c1',
          categoryName: 'Alimentação',
        ),
      ]),
    ],
  );
}
