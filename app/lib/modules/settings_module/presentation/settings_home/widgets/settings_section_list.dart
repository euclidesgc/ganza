import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/theme.dart';
import '../../../settings_routes.dart';
import '../../widgets/settings_section_tile.dart';

class SettingsSectionList extends StatelessWidget {
  const SettingsSectionList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        SettingsSectionTile(
          label: 'Conta',
          onTap: () => context.pushNamed(SettingsRoutes.accountName),
        ),
        const SizedBox(height: AppSpacing.sm),
        SettingsSectionTile(
          label: 'IA',
          onTap: () => context.pushNamed(SettingsRoutes.aiName),
        ),
        const SizedBox(height: AppSpacing.sm),
        SettingsSectionTile(
          label: 'Banco',
          onTap: () => context.pushNamed(SettingsRoutes.bankName),
        ),
      ],
    );
  }
}
