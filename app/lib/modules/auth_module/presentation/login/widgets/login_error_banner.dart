import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../login_cubit.dart';

/// O erro é anunciado como alerta e desenhado com ícone além da cor —
/// terracota sozinha não informa quem não distingue as duas.
class LoginErrorBanner extends StatelessWidget {
  const LoginErrorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LoginCubit, LoginState, String?>(
      selector: (state) => state is LoginFailed ? state.failure.message : null,
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
