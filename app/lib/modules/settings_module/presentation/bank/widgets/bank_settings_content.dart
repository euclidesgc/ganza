import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/theme/theme.dart';
import '../../../domain/entities/bank_connection_status.dart';
import '../bank_settings_cubit.dart';
import 'bank_action_failure_banner.dart';
import 'bank_connect_button.dart';
import 'bank_connection_status_card.dart';
import 'bank_disconnect_button.dart';

class BankSettingsContent extends StatelessWidget {
  const BankSettingsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocSelector<BankSettingsCubit, BankSettingsState, Failure?>(
            selector: (state) => switch (state) {
              BankSettingsActionFailed(:final failure) => failure,
              _ => null,
            },
            builder: (context, failure) =>
                BankActionFailureBanner(failure: failure),
          ),
          BlocSelector<
            BankSettingsCubit,
            BankSettingsState,
            (BankConnectionStatus, String?, DateTime?)
          >(
            selector: (state) => (
              state.displayStatus,
              state.connectionOrNull?.institution,
              state.connectionOrNull?.lastSyncedAt,
            ),
            builder: (context, data) {
              final (status, institution, lastSyncedAt) = data;
              return BankConnectionStatusCard(
                status: status,
                institution: institution,
                lastSyncedAt: lastSyncedAt,
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          BlocSelector<
            BankSettingsCubit,
            BankSettingsState,
            (BankConnectionStatus, bool)
          >(
            selector: (state) => (state.displayStatus, state.isBusy),
            builder: (context, data) {
              final (status, busy) = data;
              final canDisconnect =
                  status == BankConnectionStatus.connected ||
                  status == BankConnectionStatus.pending;

              if (canDisconnect) return BankDisconnectButton(busy: busy);

              return BankConnectButton(
                busy: busy,
                onPressed: () => context.read<BankSettingsCubit>().connect(),
              );
            },
          ),
        ],
      ),
    );
  }
}
