import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth_routes.dart';
import '../password_recovery_code_cubit.dart';

class CancelRecoveryLink extends StatelessWidget {
  const CancelRecoveryLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () {
          context.read<PasswordRecoveryCodeCubit>().cancel();
          context.goNamed(AuthRoutes.loginName);
        },
        child: const Text('Cancelar e voltar para o login'),
      ),
    );
  }
}
