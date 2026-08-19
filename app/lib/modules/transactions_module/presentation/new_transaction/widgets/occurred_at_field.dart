import 'package:flutter/material.dart';

import '../../../../../core/format/format.dart';

/// `lastDate: today` é a trava de futuro — só de UI, como pede o `specs.md`
/// §8 P8: a Edge Function aceita data futura de propósito para o chat da
/// Fase 1 do produto.
class OccurredAtField extends StatelessWidget {
  const OccurredAtField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final label = formatTransactionDate(value, now: today);

    return Semantics(
      button: true,
      label: 'Data da transação, $label',
      child: OutlinedButton.icon(
        onPressed: () => _pickDate(context, today),
        icon: const Icon(Icons.event),
        label: Align(alignment: Alignment.centerLeft, child: Text(label)),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, DateTime today) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null) onChanged(picked);
  }
}
