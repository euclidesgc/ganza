import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/theme.dart';

class ChangePasswordSuccessNotice extends StatelessWidget {
  const ChangePasswordSuccessNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Senha trocada', style: context.texts.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sua senha foi atualizada. Use a nova senha no próximo acesso.',
          style: context.texts.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          key: const Key('change-password-back-button'),
          onPressed: () => context.pop(),
          child: const Text('Voltar'),
        ),
      ],
    );
  }
}
