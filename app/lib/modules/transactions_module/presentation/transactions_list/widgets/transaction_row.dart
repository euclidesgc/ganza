import 'package:flutter/material.dart';

import '../../../../../core/format/format.dart';
import '../../../../../core/theme/theme.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/entities/transaction_direction.dart';

class TransactionRow extends StatelessWidget {
  const TransactionRow({required this.transaction, super.key});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final isOutgoing = transaction.direction == TransactionDirection.outgoing;
    final formattedAmount = formatMoney(
      isOutgoing ? -transaction.amount : transaction.amount,
    );
    final signedAmount = isOutgoing ? formattedAmount : '+$formattedAmount';
    final amountColor = isOutgoing ? context.ganza.overdue : context.ganza.done;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  transaction.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatTransactionDate(transaction.occurredAt),
                  style: context.texts.bodySmall?.copyWith(
                    color: context.ganza.mutedInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            signedAmount,
            style: AppTypography.valor.copyWith(color: amountColor),
          ),
        ],
      ),
    );
  }
}
