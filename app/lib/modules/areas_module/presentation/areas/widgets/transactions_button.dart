import 'package:flutter/material.dart';

import '../../../../../core/theme/theme.dart';
import '../../../../transactions_module/transactions_module.dart';

class TransactionsButton extends StatelessWidget {
  const TransactionsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ver transações',
      child: IconButton(
        tooltip: 'Ver transações',
        constraints: const BoxConstraints(
          minWidth: AppSpacing.touchTarget,
          minHeight: AppSpacing.touchTarget,
        ),
        onPressed: () => TransactionsRoutes.pushNamed(context),
        icon: const Icon(AppIcons.transactions),
      ),
    );
  }
}
