import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/session/session.dart';
import '../../../../../core/theme/theme.dart';
import '../../../auth_routes.dart';

class RecoveryEmailMissingNotice extends StatelessWidget {
  const RecoveryEmailMissingNotice({required this.recoveryScope, super.key});

  final PasswordRecoveryScope recoveryScope;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Não encontramos o e-mail da recuperação. Peça um novo código.',
              style: context.texts.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () {
                // Esta tela nasce sem BlocProvider — não há e-mail para
                // construir o cubit —, então desligar o escopo é feito
                // direto aqui; não existe cubit.cancel() para chamar.
                recoveryScope.end();
                context.goNamed(AuthRoutes.loginName);
              },
              child: const Text('Voltar para o login'),
            ),
          ],
        ),
      ),
    );
  }
}
