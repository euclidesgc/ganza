import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/settings_placeholder_body.dart';

class SettingsAccountPage extends StatelessWidget {
  const SettingsAccountPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      const SettingsAccountPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conta')),
      body: const SafeArea(child: SettingsPlaceholderBody(title: 'Conta')),
    );
  }
}
