import 'package:flutter/material.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/theme/theme.dart';

class AccountFailureBanner extends StatelessWidget {
  const AccountFailureBanner({required this.failure, super.key});

  final Failure? failure;

  @override
  Widget build(BuildContext context) {
    final current = failure;
    if (current == null) return const SizedBox.shrink();

    final message = switch (current) {
      NetworkFailure() => current.message,
      NotFoundFailure() => current.message,
      ValidationFailure() => current.message,
      AuthFailure() => current.message,
      PermissionFailure() => current.message,
      UnexpectedFailure() => current.message,
    };

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
            Expanded(child: Text(message, style: context.texts.bodyMedium)),
          ],
        ),
      ),
    );
  }
}
