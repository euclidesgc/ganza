import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../password_recovery_request_cubit.dart';
import 'failure_banner.dart';

class PasswordRecoveryRequestForm extends StatefulWidget {
  const PasswordRecoveryRequestForm({super.key});

  @override
  State<PasswordRecoveryRequestForm> createState() =>
      _PasswordRecoveryRequestFormState();
}

class _PasswordRecoveryRequestFormState
    extends State<PasswordRecoveryRequestForm> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<PasswordRecoveryRequestCubit>().submit(
      email: _emailController.text,
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
              Text('Recuperar senha', style: context.texts.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Informe o e-mail da conta. Enviamos um código de seis '
                'dígitos para confirmar que é você.',
                style: context.texts.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: AppSpacing.md),
              BlocSelector<
                PasswordRecoveryRequestCubit,
                PasswordRecoveryRequestState,
                String?
              >(
                selector: (state) => state is PasswordRecoveryRequestFailed
                    ? state.failure.message
                    : null,
                builder: (context, message) => FailureBanner(message: message),
              ),
              const SizedBox(height: AppSpacing.md),
              BlocSelector<
                PasswordRecoveryRequestCubit,
                PasswordRecoveryRequestState,
                bool
              >(
                selector: (state) => state is PasswordRecoveryRequestSubmitting,
                builder: (context, inProgress) => FilledButton(
                  onPressed: inProgress ? null : _submit,
                  child: Text(inProgress ? 'Enviando…' : 'Enviar código'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
