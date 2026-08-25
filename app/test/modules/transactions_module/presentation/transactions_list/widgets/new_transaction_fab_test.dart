import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/categorize_transaction.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/list_categories.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/list_transactions.dart';
import 'package:ganza/modules/transactions_module/presentation/transactions_list/transactions_list_cubit.dart';
import 'package:ganza/modules/transactions_module/presentation/transactions_list/widgets/new_transaction_fab.dart';
import 'package:ganza/modules/transactions_module/transactions_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockListTransactions extends Mock implements ListTransactions {}

class _MockListCategories extends Mock implements ListCategories {}

class _MockCategorizeTransaction extends Mock
    implements CategorizeTransaction {}

void main() {
  late TransactionsListCubit cubit;

  setUp(() {
    cubit = TransactionsListCubit(
      _MockListTransactions(),
      _MockListCategories(),
      _MockCategorizeTransaction(),
    );
  });

  tearDown(() => cubit.close());

  testWidgets('escolher Receita abre o formulário com direcao=in', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<TransactionsListCubit>.value(
            value: cubit,
            child: const Scaffold(body: NewTransactionFab()),
          ),
        ),
        GoRoute(
          path: '/transacoes/nova',
          name: TransactionsRoutes.newTransactionName,
          builder: (_, state) => Scaffold(
            body: Text(
              state.uri.queryParameters[TransactionsRoutes
                      .newTransactionDirectionQueryParameter] ??
                  'sem-direcao',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );

    await tester.tap(find.byTooltip('Adicionar transação'));
    await tester.pumpAndSettle();

    expect(find.text('O que você quer adicionar?'), findsOneWidget);
    expect(find.text('Despesa'), findsOneWidget);
    expect(find.text('Receita'), findsOneWidget);

    await tester.tap(find.text('Receita'));
    await tester.pumpAndSettle();

    expect(find.text('in'), findsOneWidget);
  });
}
