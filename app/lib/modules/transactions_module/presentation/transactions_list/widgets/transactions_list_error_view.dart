import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../transactions_list_cubit.dart';

/// Ícone + botão distinguem esta tela do estado vazio: uma falha nunca pode
/// se disfarçar de "nada aqui" (`prd.md`).
class TransactionsListErrorView extends StatelessWidget {
  const TransactionsListErrorView({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.errorState, color: context.ganza.overdue),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: () => context.read<TransactionsListCubit>().load(),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
