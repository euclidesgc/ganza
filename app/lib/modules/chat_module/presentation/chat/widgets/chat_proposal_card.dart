import 'package:flutter/material.dart';

import '../../../../../core/format/format.dart';
import '../../../../../core/theme/theme.dart';
import '../../../domain/entities/chat_proposal.dart';

class ChatProposalCard extends StatelessWidget {
  const ChatProposalCard({required this.proposal, super.key});

  final ChatProposal proposal;

  @override
  Widget build(BuildContext context) {
    final amount = proposal.payload['amount'];
    final direction = proposal.payload['direction'];
    final value = amount is int ? formatMoney(amount) : null;
    final sign = direction == 'in'
        ? '+'
        : direction == 'out'
        ? '−'
        : '';

    return Semantics(
      container: true,
      label: proposal.description,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(proposal.description, style: context.texts.bodyLarge),
              if (value != null)
                Text('$sign$value', style: AppTypography.valorGrande),
            ],
          ),
        ),
      ),
    );
  }
}
