import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/session/session.dart';
import '../../../../injection.dart';
import 'password_recovery_code_cubit.dart';
import 'widgets/password_recovery_code_view.dart';
import 'widgets/recovery_email_missing_notice.dart';

class PasswordRecoveryCodePage extends StatelessWidget {
  const PasswordRecoveryCodePage({required this.email, super.key});

  final String email;

  static Widget pageBuilder(BuildContext context, GoRouterState state) {
    final email = state.uri.queryParameters['email'];
    if (email == null || email.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: RecoveryEmailMissingNotice(
            recoveryScope: getIt<PasswordRecoveryScope>(),
          ),
        ),
      );
    }

    return BlocProvider(
      create: (_) => getIt<PasswordRecoveryCodeCubit>(),
      child: PasswordRecoveryCodePage(email: email),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: PasswordRecoveryCodeView(email: email)),
    );
  }
}
