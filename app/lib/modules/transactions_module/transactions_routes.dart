import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'presentation/new_transaction/new_transaction_page.dart';
import 'presentation/transactions_list/transactions_list_page.dart';

abstract final class TransactionsRoutes {
  static const name = 'transactions';
  static const path = '/transacoes';
  static const newTransactionName = 'transactions-new';
  static const newTransactionPath = 'nova';

  static GoRoute get route => GoRoute(
    path: path,
    name: name,
    builder: TransactionsListPage.pageBuilder,
    routes: [
      GoRoute(
        path: newTransactionPath,
        name: newTransactionName,
        builder: NewTransactionPage.pageBuilder,
      ),
    ],
  );

  static void goNamed(BuildContext context) => context.goNamed(name);

  static void pushNamed(BuildContext context) => context.pushNamed(name);

  static Future<bool?> pushNewTransactionNamed(BuildContext context) =>
      context.pushNamed<bool>(newTransactionName);
}
