import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../password_recovery_code_cubit.dart';
import 'cancel_recovery_link.dart';
import 'failure_banner.dart';

class CodeStepForm extends StatefulWidget {
  const CodeStepForm({required this.email, super.key});

  final String email;

  @override
  State<CodeStepForm> createState() => _CodeStepFormState();
}

class _CodeStepFormState extends State<CodeStepForm> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _confirm() {
    context.read<PasswordRecoveryCodeCubit>().verifyCode(
      email: widget.email,
      code: _codeController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Digite o código', style: context.texts.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Enviamos um código de seis dígitos para ${widget.email}.',
          style: context.texts.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: (_) => _confirm(),
          decoration: const InputDecoration(
            labelText: 'Código de verificação',
            hintText: '000000',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        BlocSelector<
          PasswordRecoveryCodeCubit,
          PasswordRecoveryCodeState,
          String?
        >(
          selector: (state) => state is PasswordRecoveryCodeVerifyFailed
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
          selector: (state) => state is PasswordRecoveryCodeVerifying,
          builder: (context, verifying) =>
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _codeController,
                builder: (context, value, _) {
                  final isComplete = value.text.length == 6;
                  return FilledButton(
                    onPressed: isComplete && !verifying ? _confirm : null,
                    child: Text(verifying ? 'Verificando…' : 'Confirmar'),
                  );
                },
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        const CancelRecoveryLink(),
      ],
    );
  }
}
