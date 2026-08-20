import 'package:flutter/material.dart';

class AccountDisplayNameField extends StatelessWidget {
  const AccountDisplayNameField({
    required this.controller,
    required this.enabled,
    this.hintText,
    this.errorText,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? hintText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('account-display-name-field'),
      controller: controller,
      enabled: enabled,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Nome de exibição',
        hintText: hintText,
        errorText: errorText,
      ),
    );
  }
}
