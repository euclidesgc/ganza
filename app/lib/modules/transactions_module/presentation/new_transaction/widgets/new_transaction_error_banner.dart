import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../new_transaction_cubit.dart';

class NewTransactionErrorBanner extends StatelessWidget {
  const NewTransactionErrorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<NewTransactionCubit, NewTransactionState, String?>(
      selector: (state) =>
          state is NewTransactionFailed ? state.failure.message : null,
      builder: (context, message) {
        if (message == null) return const SizedBox.shrink();

        return Semantics(
          liveRegion: true,
          container: true,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.ganza.overdueSoft,
              borderRadius: AppRadii.borderMd,
              border: Border.all(color: context.ganza.overdue),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: context.ganza.overdue),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(message, style: context.texts.bodyMedium)),
              ],
            ),
          ),
        );
      },
    );
  }
}
