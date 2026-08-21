import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import 'ai_settings_cubit.dart';
import 'widgets/ai_settings_body.dart';

class SettingsAiPage extends StatelessWidget {
  const SettingsAiPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      BlocProvider(
        create: (_) => getIt<AiSettingsCubit>()..load(),
        child: const SettingsAiPage(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IA')),
      body: const SafeArea(child: AiSettingsBody()),
    );
  }
}
