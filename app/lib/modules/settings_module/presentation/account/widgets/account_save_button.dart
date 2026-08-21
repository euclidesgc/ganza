import 'package:flutter/material.dart';

class AccountSaveButton extends StatelessWidget {
  const AccountSaveButton({
    required this.saving,
    required this.onPressed,
    super.key,
  });

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('account-save-button'),
      onPressed: saving ? null : onPressed,
      child: Text(saving ? 'Salvando…' : 'Salvar'),
    );
  }
}
