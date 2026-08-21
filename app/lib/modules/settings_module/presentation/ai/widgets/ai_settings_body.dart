import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ai_settings_cubit.dart';
import 'ai_settings_content.dart';
import 'ai_settings_load_error.dart';

class AiSettingsBody extends StatelessWidget {
  const AiSettingsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiSettingsCubit, AiSettingsState>(
      builder: (context, state) => switch (state) {
        AiSettingsLoading() => const Center(child: CircularProgressIndicator()),
        AiSettingsLoadFailed(:final failure) => AiSettingsLoadError(
          message: failure.message,
        ),
        AiSettingsReady() ||
        AiSettingsSaving() ||
        AiSettingsSaveFailed() => const AiSettingsContent(),
      },
    );
  }
}
