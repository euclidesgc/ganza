import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../auth_routes.dart';

class LoginAuthLinks extends StatelessWidget {
  const LoginAuthLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () => context.goNamed(AuthRoutes.signUpName),
          child: const Text('Criar conta'),
        ),
        TextButton(
          onPressed: () =>
              context.goNamed(AuthRoutes.passwordRecoveryRequestName),
          child: const Text('Esqueci minha senha'),
        ),
      ],
    );
  }
}
