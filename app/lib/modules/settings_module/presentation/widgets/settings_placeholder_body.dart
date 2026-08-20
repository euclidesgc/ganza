import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';

class SettingsPlaceholderBody extends StatelessWidget {
  const SettingsPlaceholderBody({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          '$title ainda não tem conteúdo aqui.',
          style: context.texts.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
