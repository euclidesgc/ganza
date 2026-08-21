import 'package:flutter/material.dart';

class AiSettingsSaveButton extends StatelessWidget {
  const AiSettingsSaveButton({
    required this.enabled,
    required this.saving,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('ai-settings-save-button'),
      onPressed: enabled ? onPressed : null,
      child: Text(saving ? 'Salvando…' : 'Salvar'),
    );
  }
}
