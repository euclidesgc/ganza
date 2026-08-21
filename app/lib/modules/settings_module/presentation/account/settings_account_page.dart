import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import 'account_cubit.dart';
import 'widgets/account_body.dart';

class SettingsAccountPage extends StatelessWidget {
  const SettingsAccountPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      BlocProvider(
        create: (_) => getIt<AccountCubit>()..load(),
        child: const SettingsAccountPage(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conta')),
      body: const SafeArea(child: AccountBody()),
    );
  }
}
