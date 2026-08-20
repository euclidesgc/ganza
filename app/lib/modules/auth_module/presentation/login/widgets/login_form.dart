import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../login_cubit.dart';
import 'ganza_wordmark.dart';
import 'login_error_banner.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController.text = context.read<LoginCubit>().lastSignedInEmail ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<LoginCubit>().signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

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
              const GanzaWordmark(),
              const SizedBox(height: AppSpacing.xxl),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'Senha'),
              ),
              const SizedBox(height: AppSpacing.md),
              const LoginErrorBanner(),
              const SizedBox(height: AppSpacing.md),
              // O botão some enquanto entra, mas o espaço não colapsa: tela
              // que pula sob o dedo faz o usuário tocar no lugar errado.
              BlocSelector<LoginCubit, LoginState, bool>(
                selector: (state) => state is LoginInProgress,
                builder: (context, inProgress) => FilledButton(
                  onPressed: inProgress ? null : _submit,
                  child: Text(inProgress ? 'Entrando…' : 'Entrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
