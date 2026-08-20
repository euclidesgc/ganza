import 'package:flutter/material.dart';

class SignUpConfirmPasswordField extends StatelessWidget {
  const SignUpConfirmPasswordField({
    required this.controller,
    required this.passwordController,
    super.key,
  });

  final TextEditingController controller;
  final TextEditingController passwordController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, passwordController]),
      builder: (context, _) {
        final text = controller.text;
        final showError = text.isNotEmpty && text != passwordController.text;
        return TextField(
          controller: controller,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Confirmar senha',
            errorText: showError ? 'As senhas não coincidem.' : null,
          ),
        );
      },
    );
  }
}
