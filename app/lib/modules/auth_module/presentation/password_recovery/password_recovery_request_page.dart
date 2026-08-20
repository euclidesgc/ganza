import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import '../../auth_routes.dart';
import 'password_recovery_request_cubit.dart';
import 'widgets/password_recovery_request_form.dart';

class PasswordRecoveryRequestPage extends StatelessWidget {
  const PasswordRecoveryRequestPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      BlocProvider(
        create: (_) => getIt<PasswordRecoveryRequestCubit>(),
        child: const PasswordRecoveryRequestPage(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child:
            BlocListener<
              PasswordRecoveryRequestCubit,
              PasswordRecoveryRequestState
            >(
              listener: (context, state) {
                if (state is! PasswordRecoveryRequestSent) return;

                context.goNamed(
                  AuthRoutes.passwordRecoveryCodeName,
                  queryParameters: {'email': state.email},
                );
              },
              child: const PasswordRecoveryRequestForm(),
            ),
      ),
    );
  }
}
