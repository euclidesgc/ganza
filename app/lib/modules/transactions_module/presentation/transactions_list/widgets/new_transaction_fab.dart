import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../../../domain/entities/transaction_direction.dart';
import '../../../transactions_routes.dart';
import '../transactions_list_cubit.dart';

class NewTransactionFab extends StatelessWidget {
  const NewTransactionFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Adicionar transação',
      child: FloatingActionButton(
        tooltip: 'Adicionar transação',
        onPressed: () => _chooseAndOpenForm(context),
        child: const Icon(AppIcons.addAction),
      ),
    );
  }

  Future<void> _chooseAndOpenForm(BuildContext context) async {
    final direction = await showModalBottomSheet<TransactionDirection>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('O que você quer adicionar?')),
            ListTile(
              leading: const Icon(AppIcons.addAction),
              title: const Text('Despesa'),
              onTap: () =>
                  Navigator.pop(sheetContext, TransactionDirection.outgoing),
            ),
            ListTile(
              leading: const Icon(AppIcons.addAction),
              title: const Text('Receita'),
              onTap: () =>
                  Navigator.pop(sheetContext, TransactionDirection.incoming),
            ),
          ],
        ),
      ),
    );
    if (direction == null || !context.mounted) return;

    final cubit = context.read<TransactionsListCubit>();
    final created =
        await TransactionsRoutes.pushNewTransactionWithDirectionNamed(
          context,
          direction,
        );
    if (created ?? false) cubit.load();
  }
}
