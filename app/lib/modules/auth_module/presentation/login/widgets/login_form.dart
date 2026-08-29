import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../../../../../core/widgets/forms/password_field.dart';
import '../../../domain/entities/biometric_login_status.dart';
import '../login_cubit.dart';
import 'ganza_wordmark.dart';
import 'login_auth_links.dart';
import 'login_error_banner.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  BiometricLoginStatus? _biometricStatus;
  bool _enableBiometrics = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = context.read<LoginCubit>().lastSignedInEmail ?? '';
    _loadBiometricStatus();
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
      enableBiometrics: _enableBiometrics,
    );
  }

  Future<void> _loadBiometricStatus() async {
    final status = await context.read<LoginCubit>().biometricLoginStatus();
    if (mounted) setState(() => _biometricStatus = status);
  }

  void _signInWithBiometrics() {
    context.read<LoginCubit>().signInWithBiometrics();
  }

  Future<void> _setBiometricLogin(bool enabled) async {
    if (enabled) {
      setState(() => _enableBiometrics = true);
      return;
    }
    if (!(_biometricStatus?.isEnabled ?? false)) {
      setState(() => _enableBiometrics = false);
      return;
    }
    await context.read<LoginCubit>().disableBiometricLogin();
    if (mounted) {
      setState(
        () => _biometricStatus = const BiometricLoginStatus(
          isSupported: true,
          isEnabled: false,
        ),
      );
    }
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
              PasswordField(
                controller: _passwordController,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                label: 'Senha',
              ),
              if (_biometricStatus?.isSupported ?? false)
                CheckboxListTile(
                  value: _enableBiometrics,
                  onChanged: (value) => _setBiometricLogin(value ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Usar digital neste aparelho'),
                  subtitle: const Text(
                    'Você poderá entrar sem digitar a senha nas próximas vezes.',
                  ),
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
              if (_biometricStatus?.isEnabled ?? false) ...[
                const SizedBox(height: AppSpacing.sm),
                BlocSelector<LoginCubit, LoginState, bool>(
                  selector: (state) => state is LoginInProgress,
                  builder: (context, inProgress) => OutlinedButton.icon(
                    onPressed: inProgress ? null : _signInWithBiometrics,
                    icon: const Icon(AppIcons.fingerprint),
                    label: const Text('Entrar com digital'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              const LoginAuthLinks(),
            ],
          ),
        ),
      ),
    );
  }
}
