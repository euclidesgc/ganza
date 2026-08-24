import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/modules/transactions_module/domain/entities/category.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction_direction.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/categorize_transaction.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/list_categories.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/list_transactions.dart';
import 'package:ganza/modules/transactions_module/presentation/transactions_list/transactions_list_cubit.dart';
import 'package:ganza/modules/transactions_module/presentation/transactions_list/widgets/transaction_row.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockListTransactions extends Mock implements ListTransactions {}

class MockListCategories extends Mock implements ListCategories {}

class MockCategorizeTransaction extends Mock implements CategorizeTransaction {}

void main() {
  late MockListTransactions listTransactions;
  late MockListCategories listCategories;
  late MockCategorizeTransaction categorizeTransaction;

  final categories = [
    Category(id: 'c1', name: 'Alimentação'),
    Category(id: 'c2', name: 'Transporte'),
  ];

  final semCategoria = Transaction(
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

  final comCategoria = Transaction(
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
  );

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    listTransactions = MockListTransactions();
    listCategories = MockListCategories();
    categorizeTransaction = MockCategorizeTransaction();
    when(
      () => listTransactions.call(),
    ).thenAnswer((_) async => const Right([]));
    when(
      () => listCategories.call(),
    ).thenAnswer((_) async => Right(categories));
  });

  Widget montar(Transaction transaction) {
    final cubit = TransactionsListCubit(
      listTransactions,
      listCategories,
      categorizeTransaction,
    );
    return MaterialApp(
      theme: AppTheme.light,
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(
          body: TransactionRow(
            transaction: transaction,
            categories: categories,
          ),
        ),
      ),
    );
  }

  testWidgets('mostra "Sem categoria" quando não há categoria', (tester) async {
    await tester.pumpWidget(montar(semCategoria));

    expect(find.text('Sem categoria'), findsOneWidget);
  });

  testWidgets('mostra o nome da categoria quando presente', (tester) async {
    await tester.pumpWidget(montar(comCategoria));

    expect(find.text('Alimentação'), findsOneWidget);
    expect(find.text('Sem categoria'), findsNothing);
  });

  testWidgets('selecionar uma categoria chama categorize', (tester) async {
    when(
      () => categorizeTransaction.call('t1', 'c2'),
    ).thenAnswer((_) async => const Right(unit));

    await tester.pumpWidget(montar(semCategoria));

    await tester.tap(find.text('Sem categoria'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transporte'));
    await tester.pumpAndSettle();

    verify(() => categorizeTransaction.call('t1', 'c2')).called(1);
  });
}
