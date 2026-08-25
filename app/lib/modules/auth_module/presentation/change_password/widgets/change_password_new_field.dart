import 'package:flutter/material.dart';

import '../../../../../core/widgets/forms/password_field.dart';

class ChangePasswordNewField extends StatelessWidget {
  const ChangePasswordNewField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return PasswordField(
      fieldKey: const Key('change-password-new-field'),
      controller: controller,
      autofillHints: const [AutofillHints.newPassword],
      textInputAction: TextInputAction.next,
      label: 'Nova senha',
    );
  }
}
