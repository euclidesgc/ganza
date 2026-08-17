import 'package:flutter/material.dart';

import '../../../../../core/theme/theme.dart';

/// Sem ícone, sem convite animado: o vazio é um fato neutro, não um convite
/// entusiasmado — §11.4 do plano proíbe celebração na interface.
class TransactionsListEmptyView extends StatelessWidget {
  const TransactionsListEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Nenhuma transação registrada.',
          textAlign: TextAlign.center,
          style: context.texts.bodyLarge?.copyWith(
            color: context.ganza.mutedInk,
          ),
        ),
      ),
    );
  }
}
