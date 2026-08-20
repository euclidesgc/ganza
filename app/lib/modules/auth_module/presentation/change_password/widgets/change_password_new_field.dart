import 'package:flutter/material.dart';

class ChangePasswordNewField extends StatelessWidget {
  const ChangePasswordNewField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('change-password-new-field'),
      controller: controller,
      obscureText: true,
      autofillHints: const [AutofillHints.newPassword],
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'Nova senha'),
    );
  }
}
