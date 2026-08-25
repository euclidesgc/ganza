import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import '../../domain/entities/transaction_direction.dart';
import '../../transactions_routes.dart';
import 'new_transaction_cubit.dart';
import 'widgets/new_transaction_form.dart';

class NewTransactionPage extends StatelessWidget {
  const NewTransactionPage({super.key, this.initialDirection});

  final TransactionDirection? initialDirection;

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      BlocProvider(
        create: (_) => getIt<NewTransactionCubit>(),
        child: NewTransactionPage(initialDirection: _directionFrom(state)),
      );

  static TransactionDirection? _directionFrom(GoRouterState state) {
    final wireValue =
        state.uri.queryParameters[TransactionsRoutes
            .newTransactionDirectionQueryParameter];
    for (final direction in TransactionDirection.values) {
      if (direction.wireValue == wireValue) return direction;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova transação')),
      body: SafeArea(
        child: NewTransactionForm(initialDirection: initialDirection),
      ),
    );
  }
}
