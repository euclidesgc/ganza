import 'package:flutter/material.dart';

import '../../../../../core/widgets/forms/password_field.dart';
import '../sign_up_validation.dart';

class SignUpPasswordField extends StatelessWidget {
  const SignUpPasswordField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final text = controller.text;
        final showError =
            text.isNotEmpty && !SignUpValidation.isPasswordValid(text);
        return PasswordField(
          controller: controller,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          label: 'Senha',
          errorText: showError
              ? 'A senha precisa ter pelo menos 6 caracteres.'
              : null,
        );
      },
    );
  }
}
