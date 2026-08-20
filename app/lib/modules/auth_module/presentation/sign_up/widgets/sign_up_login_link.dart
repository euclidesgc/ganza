import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../auth_routes.dart';

class SignUpLoginLink extends StatelessWidget {
  const SignUpLoginLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => context.goNamed(AuthRoutes.loginName),
        child: const Text('Ir para o login'),
      ),
    );
  }
}
