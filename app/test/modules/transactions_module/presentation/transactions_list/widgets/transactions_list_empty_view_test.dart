import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/modules/transactions_module/presentation/transactions_list/widgets/transactions_list_empty_view.dart';

void main() {
  testWidgets('estado vazio mostra o texto de nenhuma transação', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: TransactionsListEmptyView()),
      ),
    );

    expect(find.text('Nenhuma transação registrada.'), findsOneWidget);
  });
}
