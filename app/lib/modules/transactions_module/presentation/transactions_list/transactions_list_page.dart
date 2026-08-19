import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import 'transactions_list_cubit.dart';
import 'widgets/new_transaction_fab.dart';
import 'widgets/transactions_list_body.dart';

class TransactionsListPage extends StatelessWidget {
  const TransactionsListPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      BlocProvider(
        create: (_) => getIt<TransactionsListCubit>()..load(),
        child: const TransactionsListPage(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transações')),
      body: const SafeArea(child: TransactionsListBody()),
      floatingActionButton: const NewTransactionFab(),
    );
  }
}
