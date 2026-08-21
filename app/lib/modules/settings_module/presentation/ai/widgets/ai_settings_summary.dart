import 'package:flutter/material.dart';

import '../../../../../core/theme/theme.dart';
import '../../../domain/entities/ai_credential.dart';

class AiSettingsSummary extends StatelessWidget {
  const AiSettingsSummary({
    required this.credential,
    required this.providerLabel,
    super.key,
  });

  final AiCredential credential;
  final String providerLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'IA configurada, provedor $providerLabel, modelo ${credential.model}, '
          'chave terminada em ${credential.keyLast4}',
      child: Container(
        key: const Key('ai-settings-summary'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.ganza.doneSoft,
          borderRadius: AppRadii.borderMd,
          border: Border.all(color: context.ganza.done),
        ),
        child: Row(
          children: [
            Icon(AppIcons.connectedStatus, color: context.ganza.done),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IA configurada', style: context.texts.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$providerLabel · ${credential.model} · final ${credential.keyLast4}',
                    style: context.texts.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
