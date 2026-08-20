import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/settings_placeholder_body.dart';

class SettingsBankPage extends StatelessWidget {
  const SettingsBankPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      const SettingsBankPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banco')),
      body: const SafeArea(child: SettingsPlaceholderBody(title: 'Banco')),
    );
  }
}
