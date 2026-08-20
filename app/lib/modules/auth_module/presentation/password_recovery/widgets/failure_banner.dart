import 'package:flutter/material.dart';

import '../../../../../core/theme/theme.dart';

class FailureBanner extends StatelessWidget {
  const FailureBanner({required this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();

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
            Icon(AppIcons.errorState, color: context.ganza.overdue),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(text, style: context.texts.bodyMedium)),
          ],
        ),
      ),
    );
  }
}
