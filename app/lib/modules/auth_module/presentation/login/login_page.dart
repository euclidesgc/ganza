import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import 'login_cubit.dart';
import 'widgets/login_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      BlocProvider(
        create: (_) => getIt<LoginCubit>(),
        child: const LoginPage(),
      );

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SafeArea(child: LoginForm()));
  }
}
