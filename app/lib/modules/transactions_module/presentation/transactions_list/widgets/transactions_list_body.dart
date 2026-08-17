import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../transactions_list_cubit.dart';
import 'transaction_row.dart';
import 'transactions_list_empty_view.dart';
import 'transactions_list_error_view.dart';

class TransactionsListBody extends StatelessWidget {
  const TransactionsListBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionsListCubit, TransactionsListState>(
      builder: (context, state) => switch (state) {
        TransactionsListLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        TransactionsListLoadFailed(:final failure) => TransactionsListErrorView(
          message: failure.message,
        ),
        TransactionsListEmpty() => const TransactionsListEmptyView(),
        TransactionsListLoaded(:final transactions) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            for (final transaction in transactions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TransactionRow(transaction: transaction),
              ),
          ],
        ),
      },
    );
  }
}
