import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/theme.dart';
import '../../../auth_routes.dart';

/// Sem autoconfirm no servidor, `signUp` não devolve sessão, e o login só
/// funciona depois do e-mail confirmado — sem este aviso o usuário cadastra
/// e não entende por que não consegue entrar em seguida. O texto evita
/// afirmar que a conta foi criada agora: o GoTrue devolve `200` tanto para
/// endereço inédito quanto para um repetido, e revelar a diferença
/// exporia quais endereços têm conta (FD-024). A linha sobre recuperar a
/// senha aparece para todo mundo, sempre — é isso que a torna segura
/// (FD-025): quem só está confirmando um cadastro novo a ignora, e quem já
/// tinha conta ganha uma saída sem que a tela precise admitir o motivo.
class SignUpConfirmationNotice extends StatelessWidget {
  const SignUpConfirmationNotice({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                container: true,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.ganza.doneSoft,
                    borderRadius: AppRadii.borderMd,
                    border: Border.all(color: context.ganza.done),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verifique seu e-mail',
                        style: context.texts.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Enviamos um e-mail de confirmação para $email. '
                        'Confirme o endereço para poder entrar.',
                        style: context.texts.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Já tinha uma conta? Use "Esqueci minha senha" na '
                        'tela de entrar.',
                        style: context.texts.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => context.goNamed(AuthRoutes.loginName),
                child: const Text('Ir para o login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
