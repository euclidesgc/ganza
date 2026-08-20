import 'package:flutter/material.dart';

import '../../../../../core/theme/theme.dart';

class PasswordRecoveryCompletedNotice extends StatelessWidget {
  const PasswordRecoveryCompletedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Senha alterada', style: context.texts.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sua senha foi trocada. Você já pode continuar no ganza.',
          style: context.texts.bodyMedium,
        ),
      ],
    );
  }
}
