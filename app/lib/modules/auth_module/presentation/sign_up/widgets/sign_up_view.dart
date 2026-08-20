import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../sign_up_cubit.dart';
import 'sign_up_confirmation_notice.dart';
import 'sign_up_form.dart';

class SignUpView extends StatelessWidget {
  const SignUpView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SignUpCubit, SignUpState>(
      builder: (context, state) => switch (state) {
        SignUpInitial() => const SignUpForm(),
        SignUpInProgress() => const SignUpForm(),
        SignUpFailed() => const SignUpForm(),
        SignUpSucceeded(:final email) => SignUpConfirmationNotice(email: email),
      },
    );
  }
}
