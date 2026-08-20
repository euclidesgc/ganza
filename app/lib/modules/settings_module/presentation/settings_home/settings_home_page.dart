import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'widgets/settings_section_list.dart';

class SettingsHomePage extends StatelessWidget {
  const SettingsHomePage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      const SettingsHomePage();

  @override
  Widget build(BuildContext context) => const SettingsSectionList();
}
