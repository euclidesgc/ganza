import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import 'password_recovery_code_cubit.dart';
import 'password_recovery_code_page.dart';
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

                // As rotas /recuperar-senha ainda não existem em
                // auth_routes.dart — quem as registra é a T1.9, sequencial a
                // esta tarefa. Até lá, o passo seguinte do mesmo fluxo é
                // empurrado pelo Navigator direto, sem depender de go_router.
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => getIt<PasswordRecoveryCodeCubit>(),
                      child: PasswordRecoveryCodePage(email: state.email),
                    ),
                  ),
                );
              },
              child: const PasswordRecoveryRequestForm(),
            ),
      ),
    );
  }
}
