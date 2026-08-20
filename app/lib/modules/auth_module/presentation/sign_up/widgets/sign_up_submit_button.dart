import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../sign_up_cubit.dart';

class SignUpSubmitButton extends StatelessWidget {
  const SignUpSubmitButton({
    required this.canSubmit,
    required this.onSubmit,
    super.key,
  });

  final ValueListenable<bool> canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SignUpCubit, SignUpState, bool>(
      selector: (state) => state is SignUpInProgress,
      builder: (context, inProgress) {
        return ValueListenableBuilder<bool>(
          valueListenable: canSubmit,
          builder: (context, formValid, _) {
            final enabled = formValid && !inProgress;
            return Semantics(
              button: true,
              enabled: enabled,
              label: inProgress ? 'Criando conta' : 'Criar conta',
              child: FilledButton(
                onPressed: enabled ? onSubmit : null,
                child: Text(inProgress ? 'Criando conta…' : 'Criar conta'),
              ),
            );
          },
        );
      },
    );
  }
}
