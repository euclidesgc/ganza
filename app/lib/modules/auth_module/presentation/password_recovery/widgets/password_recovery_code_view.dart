import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../password_recovery_code_cubit.dart';
import 'code_step_form.dart';
import 'new_password_step_form.dart';
import 'password_recovery_completed_notice.dart';

class PasswordRecoveryCodeView extends StatelessWidget {
  const PasswordRecoveryCodeView({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child:
              BlocBuilder<PasswordRecoveryCodeCubit, PasswordRecoveryCodeState>(
                builder: (context, state) => switch (state) {
                  PasswordRecoveryCodeAwaitingCode() ||
                  PasswordRecoveryCodeVerifying() ||
                  PasswordRecoveryCodeVerifyFailed() => CodeStepForm(
                    email: email,
                  ),
                  PasswordRecoveryCodeAwaitingPassword() ||
                  PasswordRecoveryCodeUpdating() ||
                  PasswordRecoveryCodeUpdateFailed() =>
                    const NewPasswordStepForm(),
                  PasswordRecoveryCodeCompleted() =>
                    const PasswordRecoveryCompletedNotice(),
                },
              ),
        ),
      ),
    );
  }
}
