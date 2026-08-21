import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../bank_settings_cubit.dart';
import 'bank_disconnect_confirm_dialog.dart';

class BankDisconnectButton extends StatelessWidget {
  const BankDisconnectButton({required this.busy, super.key});

  final bool busy;

  Future<void> _confirmAndDisconnect(BuildContext context) async {
    final cubit = context.read<BankSettingsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const BankDisconnectConfirmDialog(),
    );
    if (confirmed != true) return;
    await cubit.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.touchTarget,
      child: OutlinedButton(
        key: const Key('bank-disconnect-button'),
        onPressed: busy ? null : () => _confirmAndDisconnect(context),
        child: Text(busy ? 'Desconectando…' : 'Desconectar'),
      ),
    );
  }
}
