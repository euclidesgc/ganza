import 'package:flutter/material.dart';

class ChangePasswordSubmitButton extends StatelessWidget {
  const ChangePasswordSubmitButton({
    required this.enabled,
    required this.submitting,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final bool submitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('change-password-submit-button'),
      onPressed: enabled && !submitting ? onPressed : null,
      child: Text(submitting ? 'Trocando…' : 'Trocar senha'),
    );
  }
}
