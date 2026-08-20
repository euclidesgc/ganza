import 'package:flutter/material.dart';

class AccountEmailField extends StatelessWidget {
  const AccountEmailField({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('account-email-field'),
      controller: TextEditingController(text: email),
      readOnly: true,
      decoration: const InputDecoration(
        labelText: 'E-mail',
        helperText:
            'Para trocar de e-mail, é preciso confirmar o novo endereço — '
            'isso acontece em outro fluxo, fora daqui.',
        helperMaxLines: 2,
      ),
    );
  }
}
