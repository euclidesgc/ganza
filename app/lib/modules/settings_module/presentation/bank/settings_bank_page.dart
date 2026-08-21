import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import 'bank_settings_cubit.dart';
import 'widgets/bank_settings_body.dart';

class SettingsBankPage extends StatelessWidget {
  const SettingsBankPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      BlocProvider(
        create: (_) => getIt<BankSettingsCubit>()..load(),
        child: const SettingsBankPage(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banco')),
      body: const SafeArea(child: BankSettingsBody()),
    );
  }
}
