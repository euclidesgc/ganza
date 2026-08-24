import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/format/format.dart';
import '../../../../../core/theme/theme.dart';
import '../../../domain/entities/routine_occurrence.dart';
import '../routines_cubit.dart';

class RoutineOccurrenceCard extends StatelessWidget {
  const RoutineOccurrenceCard({
    required this.occurrence,
    this.completionRate,
    super.key,
  });

  final RoutineOccurrence occurrence;
  final double? completionRate;

  void _postpone(BuildContext context) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final due =
        '${tomorrow.year.toString().padLeft(4, '0')}-'
        '${tomorrow.month.toString().padLeft(2, '0')}-'
        '${tomorrow.day.toString().padLeft(2, '0')}';
    context.read<RoutinesCubit>().resolve(
      occurrence.id,
      'postpone',
      dueDate: due,
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.select<RoutinesCubit, bool>(
      (cubit) =>
          cubit.state is RoutinesReady &&
          (cubit.state as RoutinesReady).busyIds.contains(occurrence.id),
    );
    final overdue = occurrence.isOverdueOn(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    occurrence.routineName,
                    style: context.texts.bodyLarge,
                  ),
                ),
                if (overdue)
                  Text(
                    'Atrasada',
                    style: context.texts.bodySmall?.copyWith(
                      color: context.ganza.overdue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatTransactionDate(occurrence.dueDate),
              style: context.texts.bodySmall?.copyWith(
                color: context.ganza.mutedInk,
              ),
            ),
            if (completionRate != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${(completionRate! * 100).round()}% feitas',
                style: context.texts.bodySmall?.copyWith(
                  color: context.ganza.mutedInk,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => context.read<RoutinesCubit>().resolve(
                          occurrence.id,
                          'done',
                        ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.touchTarget),
                  ),
                  child: const Text('Feita'),
                ),
                TextButton(
                  onPressed: busy ? null : () => _postpone(context),
                  child: const Text('Adiar'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => context.read<RoutinesCubit>().resolve(
                          occurrence.id,
                          'skip',
                        ),
                  child: const Text('Pular'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => context.read<RoutinesCubit>().resolve(
                          occurrence.id,
                          'cancel',
                        ),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
