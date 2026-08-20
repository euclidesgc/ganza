import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth_routes.dart';
import '../password_recovery_code_cubit.dart';

class SignOutWithoutChangingPasswordLink extends StatefulWidget {
  const SignOutWithoutChangingPasswordLink({super.key});

  @override
  State<SignOutWithoutChangingPasswordLink> createState() =>
      _SignOutWithoutChangingPasswordLinkState();
}

class _SignOutWithoutChangingPasswordLinkState
    extends State<SignOutWithoutChangingPasswordLink> {
  bool _leaving = false;

  Future<void> _leave() async {
    setState(() => _leaving = true);
    await context
        .read<PasswordRecoveryCodeCubit>()
        .signOutWithoutChangingPassword();
    if (!mounted) return;
    context.goNamed(AuthRoutes.loginName);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: _leaving ? null : _leave,
        child: const Text('Sair sem trocar a senha'),
      ),
    );
  }
}
