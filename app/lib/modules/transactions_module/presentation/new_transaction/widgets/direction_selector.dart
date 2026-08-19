import 'package:flutter/material.dart';

import '../../../../../core/theme/theme.dart';
import '../../../domain/entities/transaction_direction.dart';

extension on TransactionDirection {
  String get label => switch (this) {
    TransactionDirection.outgoing => 'Despesa',
    TransactionDirection.incoming => 'Receita',
  };
}

class DirectionSelector extends StatelessWidget {
  const DirectionSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final TransactionDirection value;
  final ValueChanged<TransactionDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Direção da transação',
      child: SegmentedButton<TransactionDirection>(
        segments: [
          for (final direction in TransactionDirection.values)
            ButtonSegment(value: direction, label: Text(direction.label)),
        ],
        selected: {value},
        showSelectedIcon: true,
        onSelectionChanged: (selection) => onChanged(selection.first),
        style: SegmentedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
        ),
      ),
    );
  }
}
