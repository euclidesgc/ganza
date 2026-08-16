import 'package:flutter/material.dart';

import '../../../../../core/theme/theme.dart';
import 'day_grain.dart';

/// A faixa de pulso: um grão por dia da semana. É o vocabulário da marca
/// virando interface — o mesmo desenho no logo e na tela.
class WeekPulse extends StatelessWidget {
  const WeekPulse({super.key, this.completedDays = const []});

  final List<bool> completedDays;

  static const _labels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Esta semana', style: context.texts.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var day = 0; day < _labels.length; day++)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: DayGrain(
                  label: _labels[day],
                  completed: day < completedDays.length && completedDays[day],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
