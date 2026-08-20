import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../password_recovery_code_cubit.dart';
import 'failure_banner.dart';
import 'sign_out_without_changing_password_link.dart';

class NewPasswordStepForm extends StatefulWidget {
  const NewPasswordStepForm({super.key});

  @override
  State<NewPasswordStepForm> createState() => _NewPasswordStepFormState();
}

class _NewPasswordStepFormState extends State<NewPasswordStepForm> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<PasswordRecoveryCodeCubit>().submitNewPassword(
      newPassword: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Defina a nova senha', style: context.texts.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Código confirmado. Escolha uma nova senha.',
          style: context.texts.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _passwordController,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Nova senha'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _confirmController,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(labelText: 'Confirme a nova senha'),
        ),
        const SizedBox(height: AppSpacing.md),
        BlocSelector<
          PasswordRecoveryCodeCubit,
          PasswordRecoveryCodeState,
          String?
        >(
          selector: (state) => state is PasswordRecoveryCodeUpdateFailed
              ? state.failure.message
              : null,
          builder: (context, message) => FailureBanner(message: message),
        ),
        const SizedBox(height: AppSpacing.md),
        BlocSelector<
          PasswordRecoveryCodeCubit,
          PasswordRecoveryCodeState,
          bool
        >(
          selector: (state) => state is PasswordRecoveryCodeUpdating,
          builder: (context, updating) => ListenableBuilder(
            listenable: Listenable.merge([
              _passwordController,
              _confirmController,
            ]),
            builder: (context, _) {
              final canSubmit =
                  _passwordController.text.isNotEmpty &&
                  _passwordController.text == _confirmController.text;
              return FilledButton(
                onPressed: canSubmit && !updating ? _submit : null,
                child: Text(updating ? 'Salvando…' : 'Salvar nova senha'),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const SignOutWithoutChangingPasswordLink(),
      ],
    );
  }
}
