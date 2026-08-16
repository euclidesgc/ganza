import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Um grão do chocalho. O estado não vem só da cor: o rótulo semântico diz
/// "cumprido" ou "sem registro" para quem não distingue as duas.
class DayGrain extends StatelessWidget {
  const DayGrain({required this.label, required this.completed, super.key});

  final String label;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    // `container` + `excludeSemantics` fazem o grão virar UM nó: sem isso o
    // leitor de tela anuncia o rótulo e depois repete a letra solta.
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: completed ? '$label, cumprido' : '$label, sem registro',
      child: Column(
        children: [
          Container(
            width: AppSpacing.lg,
            height: AppSpacing.lg,
            decoration: BoxDecoration(
              color: completed
                  ? context.ganza.done
                  : context.ganza.elevatedSurface,
              shape: BoxShape.circle,
              border: Border.all(color: context.ganza.outline),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: context.texts.bodySmall?.copyWith(
              color: context.ganza.mutedInk,
            ),
          ),
        ],
      ),
    );
  }
}
