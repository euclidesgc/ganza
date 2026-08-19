import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../transactions_routes.dart';
import '../transactions_list_cubit.dart';

class NewTransactionFab extends StatelessWidget {
  const NewTransactionFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Registrar transação',
      child: FloatingActionButton(
        tooltip: 'Registrar transação',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openForm(BuildContext context) async {
    final cubit = context.read<TransactionsListCubit>();
    final created = await TransactionsRoutes.pushNewTransactionNamed(context);
    if (created ?? false) cubit.load();
  }
}
