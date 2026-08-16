import 'package:flutter/material.dart';

import '../../../../../core/theme/theme.dart';
import '../../../../../core/widgets/widgets.dart';

class GanzaWordmark extends StatelessWidget {
  const GanzaWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const GanzaMark(height: 40),
        const SizedBox(height: AppSpacing.md),
        Text('Ganzá', style: context.texts.displayMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Registre em dez segundos. O resto é com ele.',
          textAlign: TextAlign.center,
          style: context.texts.bodyMedium?.copyWith(
            color: context.ganza.mutedInk,
          ),
        ),
      ],
    );
  }
}
