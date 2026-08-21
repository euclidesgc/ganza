import 'package:flutter/material.dart';

import '../../../domain/entities/ai_provider_kind.dart';

class AiSettingsProviderDropdown extends StatelessWidget {
  const AiSettingsProviderDropdown({
    required this.providerKinds,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<AiProviderKind> providerKinds;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: const Key('ai-settings-provider-dropdown'),
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Provedor'),
      items: [
        for (final kind in providerKinds)
          DropdownMenuItem(value: kind.id, child: Text(kind.label)),
      ],
      onChanged: onChanged,
    );
  }
}
