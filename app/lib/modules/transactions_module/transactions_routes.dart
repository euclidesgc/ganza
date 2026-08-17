import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'presentation/transactions_list/transactions_list_page.dart';

abstract final class TransactionsRoutes {
  static const name = 'transactions';
  static const path = '/transacoes';

  static GoRoute get route => GoRoute(
    path: path,
    name: name,
    builder: TransactionsListPage.pageBuilder,
  );

  static void goNamed(BuildContext context) => context.goNamed(name);

  static void pushNamed(BuildContext context) => context.pushNamed(name);
}
