import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import 'new_transaction_cubit.dart';
import 'widgets/new_transaction_form.dart';

class NewTransactionPage extends StatelessWidget {
  const NewTransactionPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      BlocProvider(
        create: (_) => getIt<NewTransactionCubit>(),
        child: const NewTransactionPage(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova transação')),
      body: const SafeArea(child: NewTransactionForm()),
    );
  }
}
