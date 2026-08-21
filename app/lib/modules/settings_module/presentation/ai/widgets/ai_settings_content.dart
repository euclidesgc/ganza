import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../../../domain/entities/ai_credential.dart';
import '../../../domain/entities/ai_provider_kind.dart';
import '../ai_settings_cubit.dart';
import 'ai_settings_form.dart';
import 'ai_settings_summary.dart';

String _providerLabel(
  List<AiProviderKind> providerKinds,
  String providerKindId,
) {
  for (final kind in providerKinds) {
    if (kind.id == providerKindId) return kind.label;
  }
  return providerKindId;
}

class AiSettingsContent extends StatelessWidget {
  const AiSettingsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocSelector<
            AiSettingsCubit,
            AiSettingsState,
            (AiCredential?, List<AiProviderKind>)
          >(
            selector: (state) =>
                (state.credentialOrNull, state.providerKindsOrEmpty),
            builder: (context, data) {
              final (credential, providerKinds) = data;
              if (credential == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: AiSettingsSummary(
                  credential: credential,
                  providerLabel: _providerLabel(
                    providerKinds,
                    credential.providerKindId,
                  ),
                ),
              );
            },
          ),
          const AiSettingsForm(),
        ],
      ),
    );
  }
}
