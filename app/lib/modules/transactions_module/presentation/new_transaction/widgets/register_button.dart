import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../new_transaction_cubit.dart';

class RegisterButton extends StatelessWidget {
  const RegisterButton({
    required this.isValid,
    required this.onPressed,
    super.key,
  });

  final ValueListenable<bool> isValid;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isValid,
      builder: (context, valid, _) {
        return BlocSelector<NewTransactionCubit, NewTransactionState, bool>(
          selector: (state) => state is NewTransactionSubmitting,
          builder: (context, submitting) {
            final enabled = valid && !submitting;
            final label = submitting ? 'Registrando…' : 'Registrar';

            return Semantics(
              button: true,
              label: label,
              enabled: enabled,
              child: FilledButton(
                onPressed: enabled ? onPressed : null,
                child: Text(label),
              ),
            );
          },
        );
      },
    );
  }
}
