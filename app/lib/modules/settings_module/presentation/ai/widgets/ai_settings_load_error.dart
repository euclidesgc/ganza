import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../ai_settings_cubit.dart';

class AiSettingsLoadError extends StatelessWidget {
  const AiSettingsLoadError({required this.message, super.key});

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
              onPressed: () => context.read<AiSettingsCubit>().load(),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
