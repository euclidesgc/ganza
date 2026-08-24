import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/theme/theme.dart';
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

Future<void> _carregarFontes() async {
  await (FontLoader(
    AppTypography.familiaCorpo,
  )..addFont(rootBundle.load('assets/fonts/IBMPlexSans.ttf'))).load();
  await (FontLoader(
    AppTypography.familiaTitulo,
  )..addFont(rootBundle.load('assets/fonts/Fraunces.ttf'))).load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _carregarFontes();
    await initializeDateFormatting('pt_BR');
  });

  final categories = [Category(id: 'c1', name: 'Alimentação')];

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

  Widget montar(Transaction transaction) {
    final cubit = TransactionsListCubit(
      MockListTransactions(),
      MockListCategories(),
      MockCategorizeTransaction(),
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

  testWidgets('golden da linha sem categoria', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 120));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(montar(semCategoria));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(TransactionRow),
      matchesGoldenFile('goldens/transaction_row_sem_categoria.png'),
    );
  });

  testWidgets('golden da linha com categoria', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 120));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(montar(comCategoria));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(TransactionRow),
      matchesGoldenFile('goldens/transaction_row_com_categoria.png'),
    );
  });
}
