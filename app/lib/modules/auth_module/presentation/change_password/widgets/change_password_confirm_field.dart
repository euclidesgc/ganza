import 'package:flutter/material.dart';

class ChangePasswordConfirmField extends StatelessWidget {
  const ChangePasswordConfirmField({
    required this.controller,
    required this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('change-password-confirm-field'),
      controller: controller,
      obscureText: true,
      autofillHints: const [AutofillHints.newPassword],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onSubmitted(),
      decoration: const InputDecoration(labelText: 'Confirme a nova senha'),
    );
  }
}
