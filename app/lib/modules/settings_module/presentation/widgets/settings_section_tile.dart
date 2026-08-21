import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';

class SettingsSectionTile extends StatelessWidget {
  const SettingsSectionTile({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: context.colors.surface,
        borderRadius: AppRadii.borderMd,
        child: InkWell(
          borderRadius: AppRadii.borderMd,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.touchTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            alignment: Alignment.centerLeft,
            child: Text(label, style: context.texts.titleMedium),
          ),
        ),
      ),
    );
  }
}
