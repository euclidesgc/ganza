import 'package:flutter/material.dart';

import '../../../../../core/theme/theme.dart';

class BankConnectButton extends StatelessWidget {
  const BankConnectButton({
    required this.busy,
    required this.onPressed,
    super.key,
  });

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.touchTarget,
      child: FilledButton(
        key: const Key('bank-connect-button'),
        onPressed: busy ? null : onPressed,
        child: Text(busy ? 'Conectando…' : 'Conectar banco'),
      ),
    );
  }
}
