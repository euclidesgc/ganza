import 'package:flutter/material.dart';

import '../../theme/theme.dart';

class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({required this.title, super.key});

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
