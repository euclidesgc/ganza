import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../change_password_cubit.dart';
import 'change_password_form.dart';
import 'change_password_success_notice.dart';

class ChangePasswordView extends StatelessWidget {
  const ChangePasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: BlocBuilder<ChangePasswordCubit, ChangePasswordState>(
            builder: (context, state) => switch (state) {
              ChangePasswordSucceeded() => const ChangePasswordSuccessNotice(),
              ChangePasswordInitial() ||
              ChangePasswordInProgress() ||
              ChangePasswordFailed() => const ChangePasswordForm(),
            },
          ),
        ),
      ),
    );
  }
}
