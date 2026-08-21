import 'package:flutter/material.dart';

class ChangePasswordCurrentField extends StatelessWidget {
  const ChangePasswordCurrentField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('change-password-current-field'),
      controller: controller,
      obscureText: true,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'Senha atual'),
    );
  }
}
