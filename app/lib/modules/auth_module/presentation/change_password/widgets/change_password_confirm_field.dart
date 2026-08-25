import 'package:flutter/material.dart';

import '../../../../../core/widgets/forms/password_field.dart';

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
    return PasswordField(
      fieldKey: const Key('change-password-confirm-field'),
      controller: controller,
      autofillHints: const [AutofillHints.newPassword],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onSubmitted(),
      label: 'Confirme a nova senha',
    );
  }
}
