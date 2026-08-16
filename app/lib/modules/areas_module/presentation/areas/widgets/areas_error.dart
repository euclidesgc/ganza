import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../areas_cubit.dart';

class AreasError extends StatelessWidget {
  const AreasError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: context.ganza.overdue),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: () => context.read<AreasCubit>().load(),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
