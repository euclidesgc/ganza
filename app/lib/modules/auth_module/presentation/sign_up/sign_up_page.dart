import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import 'sign_up_cubit.dart';
import 'widgets/sign_up_view.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      BlocProvider(
        create: (_) => getIt<SignUpCubit>(),
        child: const SignUpPage(),
      );

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SafeArea(child: SignUpView()));
  }
}
