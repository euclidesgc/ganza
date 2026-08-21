import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bank_settings_cubit.dart';
import 'bank_settings_content.dart';
import 'bank_settings_load_error.dart';

class BankSettingsBody extends StatelessWidget {
  const BankSettingsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BankSettingsCubit, BankSettingsState>(
      builder: (context, state) => switch (state) {
        BankSettingsLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        BankSettingsLoadFailed(:final failure) => BankSettingsLoadError(
          message: failure.message,
        ),
        BankSettingsReady() ||
        BankSettingsConnecting() ||
        BankSettingsDisconnecting() ||
        BankSettingsActionFailed() => const BankSettingsContent(),
      },
    );
  }
}
