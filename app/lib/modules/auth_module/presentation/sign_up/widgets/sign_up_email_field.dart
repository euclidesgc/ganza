import 'package:flutter/material.dart';

import '../sign_up_validation.dart';

class SignUpEmailField extends StatelessWidget {
  const SignUpEmailField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final text = controller.text;
        final showError =
            text.isNotEmpty && !SignUpValidation.isEmailValid(text);
        return TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'E-mail',
            errorText: showError ? 'Informe um e-mail válido.' : null,
          ),
        );
      },
    );
  }
}
