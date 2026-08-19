import 'package:flutter/material.dart';

class DescriptionField extends StatelessWidget {
  const DescriptionField({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  static const _maxLength = 200;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: 'Descrição da transação',
      child: TextField(
        controller: controller,
        maxLength: _maxLength,
        textInputAction: TextInputAction.next,
        onChanged: onChanged,
        decoration: const InputDecoration(labelText: 'Descrição'),
      ),
    );
  }
}
