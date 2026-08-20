import 'package:flutter/material.dart';

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
        return TextField(
          controller: controller,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Senha',
            errorText: showError
                ? 'A senha precisa ter pelo menos 6 caracteres.'
                : null,
          ),
        );
      },
    );
  }
}
