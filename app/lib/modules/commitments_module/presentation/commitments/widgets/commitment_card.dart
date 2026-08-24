import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/format/format.dart';
import '../../../../../core/theme/theme.dart';
import '../../../domain/entities/commitment.dart';
import '../../../domain/entities/commitment_direction.dart';
import '../../../domain/entities/payoff_simulation.dart';
import '../commitments_cubit.dart';

class CommitmentCard extends StatelessWidget {
  const CommitmentCard({
    required this.commitment,
    this.simulation,
    this.busy = false,
    super.key,
  });

  final Commitment commitment;
  final PayoffSimulation? simulation;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isInstallment =
        commitment.valueMode == 'installment' &&
        commitment.totalAmount != null &&
        commitment.installmentsTotal != null;
    final total = commitment.totalAmount;
    final signed = total == null
        ? null
        : commitment.direction == CommitmentDirection.incoming
        ? formatMoney(total)
        : formatMoney(-total);
    final rate = commitment.interestRateMonthly;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(commitment.name, style: context.texts.bodyLarge),
            if (signed != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(signed, style: AppTypography.valorGrande),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                commitment.valueMode,
                if (commitment.amortizationSystem != null)
                  commitment.amortizationSystem!,
                if (rate != null) '${(rate * 100).toStringAsFixed(2)}% a.m.',
              ].join(' · '),
              style: context.texts.bodySmall?.copyWith(
                color: context.ganza.mutedInk,
              ),
            ),
            if (isInstallment) ...[
              const SizedBox(height: AppSpacing.sm),
              if (simulation == null)
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => context.read<CommitmentsCubit>().simulate(
                          commitment.id,
                        ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.touchTarget),
                  ),
                  child: const Text('Simular quitação'),
                )
              else
                Text(
                  'Quitar por ${formatMoney(simulation!.presentValue)} '
                  '(economia de juros ${formatMoney(simulation!.interestSaved)})',
                  style: context.texts.bodySmall,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
