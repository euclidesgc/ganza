import 'package:flutter/material.dart';

import '../../../../../core/theme/theme.dart';
import '../../../domain/entities/area.dart';

class AreaTile extends StatelessWidget {
  const AreaTile({required this.area, super.key});

  final Area area;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.ganza.elevatedSurface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: context.ganza.outline),
      ),
      child: Row(
        children: [
          Expanded(child: Text(area.name, style: context.texts.bodyLarge)),
          Text(
            'vazia',
            style: context.texts.bodySmall?.copyWith(
              color: context.ganza.mutedInk,
            ),
          ),
        ],
      ),
    );
  }
}
