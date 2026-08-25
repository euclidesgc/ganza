import 'package:flutter/material.dart';

import '../../../../../core/widgets/forms/password_field.dart';

class ChangePasswordCurrentField extends StatelessWidget {
  const ChangePasswordCurrentField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return PasswordField(
      fieldKey: const Key('change-password-current-field'),
      controller: controller,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.next,
      label: 'Senha atual',
    );
  }
}
