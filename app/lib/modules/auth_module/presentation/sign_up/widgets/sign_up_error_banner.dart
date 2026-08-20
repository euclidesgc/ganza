import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../sign_up_cubit.dart';

/// O erro é anunciado como alerta e desenhado com ícone além da cor —
/// terracota sozinha não informa quem não distingue as duas.
class SignUpErrorBanner extends StatelessWidget {
  const SignUpErrorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SignUpCubit, SignUpState, String?>(
      selector: (state) => state is SignUpFailed ? state.failure.message : null,
      builder: (context, message) {
        if (message == null) return const SizedBox.shrink();

        return Semantics(
          liveRegion: true,
          container: true,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.ganza.overdueSoft,
              borderRadius: AppRadii.borderMd,
              border: Border.all(color: context.ganza.overdue),
            ),
            child: Row(
              children: [
                Icon(AppIcons.errorState, color: context.ganza.overdue),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(message, style: context.texts.bodyMedium)),
              ],
            ),
          ),
        );
      },
    );
  }
}
