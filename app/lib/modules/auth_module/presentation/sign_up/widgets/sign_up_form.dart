import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../sign_up_cubit.dart';
import '../sign_up_validation.dart';
import 'sign_up_confirm_password_field.dart';
import 'sign_up_email_field.dart';
import 'sign_up_error_banner.dart';
import 'sign_up_login_link.dart';
import 'sign_up_password_field.dart';
import 'sign_up_submit_button.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _canSubmit = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_revalidate);
    _passwordController.addListener(_revalidate);
    _confirmPasswordController.addListener(_revalidate);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _canSubmit.dispose();
    super.dispose();
  }

  void _revalidate() {
    _canSubmit.value =
        SignUpValidation.isEmailValid(_emailController.text) &&
        SignUpValidation.isPasswordValid(_passwordController.text) &&
        _passwordController.text == _confirmPasswordController.text;
  }

  void _submit() {
    context.read<SignUpCubit>().signUp(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Criar conta', style: context.texts.headlineMedium),
              const SizedBox(height: AppSpacing.xl),
              SignUpEmailField(controller: _emailController),
              const SizedBox(height: AppSpacing.md),
              SignUpPasswordField(controller: _passwordController),
              const SizedBox(height: AppSpacing.md),
              SignUpConfirmPasswordField(
                controller: _confirmPasswordController,
                passwordController: _passwordController,
              ),
              const SizedBox(height: AppSpacing.md),
              const SignUpErrorBanner(),
              const SizedBox(height: AppSpacing.md),
              SignUpSubmitButton(canSubmit: _canSubmit, onSubmit: _submit),
              const SizedBox(height: AppSpacing.sm),
              const SignUpLoginLink(),
            ],
          ),
        ),
      ),
    );
  }
}
