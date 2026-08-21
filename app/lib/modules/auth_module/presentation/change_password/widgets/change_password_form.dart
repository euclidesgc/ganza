import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/theme/theme.dart';
import '../change_password_cubit.dart';
import 'change_password_confirm_field.dart';
import 'change_password_current_field.dart';
import 'change_password_failure_banner.dart';
import 'change_password_new_field.dart';
import 'change_password_submit_button.dart';

class ChangePasswordForm extends StatefulWidget {
  const ChangePasswordForm({super.key});

  @override
  State<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<ChangePasswordForm> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<ChangePasswordCubit>().submit(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Trocar senha', style: context.texts.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Confirme a senha atual e escolha a nova.',
          style: context.texts.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        ChangePasswordCurrentField(controller: _currentController),
        const SizedBox(height: AppSpacing.md),
        ChangePasswordNewField(controller: _newController),
        const SizedBox(height: AppSpacing.md),
        ChangePasswordConfirmField(
          controller: _confirmController,
          onSubmitted: _submit,
        ),
        const SizedBox(height: AppSpacing.md),
        BlocSelector<ChangePasswordCubit, ChangePasswordState, Failure?>(
          selector: (state) =>
              state is ChangePasswordFailed ? state.failure : null,
          builder: (context, failure) =>
              ChangePasswordFailureBanner(failure: failure),
        ),
        const SizedBox(height: AppSpacing.md),
        BlocSelector<ChangePasswordCubit, ChangePasswordState, bool>(
          selector: (state) => state is ChangePasswordInProgress,
          builder: (context, submitting) => ListenableBuilder(
            listenable: Listenable.merge([
              _currentController,
              _newController,
              _confirmController,
            ]),
            builder: (context, _) {
              final newPasswordMatches =
                  _newController.text.isNotEmpty &&
                  _newController.text == _confirmController.text;
              final enabled =
                  _currentController.text.isNotEmpty && newPasswordMatches;
              return ChangePasswordSubmitButton(
                enabled: enabled,
                submitting: submitting,
                onPressed: _submit,
              );
            },
          ),
        ),
      ],
    );
  }
}
