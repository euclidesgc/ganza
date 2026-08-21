import 'package:flutter/material.dart';

import '../../../../../core/format/date_formatter.dart';
import '../../../../../core/theme/theme.dart';
import '../../../domain/entities/bank_connection_status.dart';

class BankConnectionStatusCard extends StatelessWidget {
  const BankConnectionStatusCard({
    required this.status,
    required this.institution,
    required this.lastSyncedAt,
    super.key,
  });

  final BankConnectionStatus status;
  final String? institution;
  final DateTime? lastSyncedAt;

  @override
  Widget build(BuildContext context) {
    final (label, icon, foreground, background) = switch (status) {
      BankConnectionStatus.connected => (
        'Banco conectado',
        AppIcons.connectedStatus,
        context.ganza.done,
        context.ganza.doneSoft,
      ),
      BankConnectionStatus.pending => (
        'Conexão pendente',
        AppIcons.bank,
        context.ganza.forecast,
        context.ganza.elevatedSurface,
      ),
      BankConnectionStatus.error => (
        'Erro na conexão',
        AppIcons.errorState,
        context.ganza.overdue,
        context.ganza.overdueSoft,
      ),
      BankConnectionStatus.disconnected => (
        'Banco desconectado',
        AppIcons.notConfiguredStatus,
        context.ganza.mutedInk,
        context.ganza.elevatedSurface,
      ),
    };

    final syncedAt = lastSyncedAt;
    final subtitle = [
      ?institution,
      if (syncedAt != null)
        'última sincronização ${formatTransactionDate(syncedAt)}',
    ].join(' · ');

    return Semantics(
      container: true,
      label: subtitle.isEmpty ? label : '$label, $subtitle',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadii.borderMd,
          border: Border.all(color: foreground),
        ),
        child: Row(
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.texts.titleMedium),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle, style: context.texts.bodyMedium),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
