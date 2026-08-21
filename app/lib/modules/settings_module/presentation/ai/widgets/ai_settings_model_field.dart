import 'package:flutter/material.dart';

class AiSettingsModelField extends StatelessWidget {
  const AiSettingsModelField({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('ai-settings-model-field'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Modelo',
        hintText: 'Nome do modelo, como está no provedor',
      ),
    );
  }
}
