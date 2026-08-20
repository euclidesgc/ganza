import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/settings_placeholder_body.dart';

class SettingsAiPage extends StatelessWidget {
  const SettingsAiPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      const SettingsAiPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IA')),
      body: const SafeArea(child: SettingsPlaceholderBody(title: 'IA')),
    );
  }
}
