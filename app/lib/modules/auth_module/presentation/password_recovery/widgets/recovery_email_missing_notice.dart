import 'package:flutter/material.dart';

import '../../../../../core/theme/theme.dart';

class RecoveryEmailMissingNotice extends StatelessWidget {
  const RecoveryEmailMissingNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Não encontramos o e-mail da recuperação. Peça um novo código.',
          style: context.texts.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
