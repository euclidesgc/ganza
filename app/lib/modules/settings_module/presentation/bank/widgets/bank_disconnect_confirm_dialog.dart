import 'package:flutter/material.dart';

class BankDisconnectConfirmDialog extends StatelessWidget {
  const BankDisconnectConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Desconectar banco?'),
      content: const Text(
        'O ganzá para de ler os dados dessa conexão bancária. Você pode '
        'conectar de novo quando quiser.',
      ),
      actions: [
        TextButton(
          key: const Key('bank-disconnect-confirm-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('bank-disconnect-confirm-accept'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Desconectar'),
        ),
      ],
    );
  }
}
