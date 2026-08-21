import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/theme/theme.dart';
import '../../../../../core/widgets/forms/secret_field.dart';
import '../../../domain/entities/ai_provider_kind.dart';
import '../ai_settings_cubit.dart';
import 'ai_settings_error_banner.dart';
import 'ai_settings_model_field.dart';
import 'ai_settings_provider_dropdown.dart';
import 'ai_settings_save_button.dart';

class AiSettingsForm extends StatefulWidget {
  const AiSettingsForm({super.key});

  @override
  State<AiSettingsForm> createState() => _AiSettingsFormState();
}

class _AiSettingsFormState extends State<AiSettingsForm> {
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  String? _providerKindId;

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController();
    _apiKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _providerKindId != null &&
      _modelController.text.trim().isNotEmpty &&
      _apiKeyController.text.trim().isNotEmpty;

  void _onFieldsChanged(String _) => setState(() {});

  void _onProviderChanged(String? value) {
    setState(() => _providerKindId = value);
  }

  void _save() {
    final providerKindId = _providerKindId;
    if (providerKindId == null) return;
    context.read<AiSettingsCubit>().save(
      providerKindId: providerKindId,
      model: _modelController.text,
      apiKey: _apiKeyController.text,
    );
  }

  // O sucesso limpa a chave digitada — ela é write-only e não tem por que
  // continuar viva num TextEditingController depois de já ter sido enviada.
  // O erro, ao contrário, preserva: é o servidor que falhou, não o usuário.
  void _clearAfterSuccess(BuildContext context, AiSettingsState state) {
    if (state is! AiSettingsReady) return;
    _modelController.clear();
    _apiKeyController.clear();
    setState(() => _providerKindId = null);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AiSettingsCubit, AiSettingsState>(
      listenWhen: (previous, current) =>
          previous is AiSettingsSaving && current is AiSettingsReady,
      listener: _clearAfterSuccess,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocSelector<AiSettingsCubit, AiSettingsState, List<AiProviderKind>>(
            selector: (state) => state.providerKindsOrEmpty,
            builder: (context, providerKinds) => AiSettingsProviderDropdown(
              providerKinds: providerKinds,
              value: _providerKindId,
              onChanged: _onProviderChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AiSettingsModelField(
            controller: _modelController,
            onChanged: _onFieldsChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          SecretField(
            label: 'Chave de API',
            controller: _apiKeyController,
            onChanged: _onFieldsChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          BlocSelector<AiSettingsCubit, AiSettingsState, Failure?>(
            selector: (state) =>
                state is AiSettingsSaveFailed ? state.failure : null,
            builder: (context, failure) =>
                AiSettingsErrorBanner(failure: failure),
          ),
          const SizedBox(height: AppSpacing.md),
          BlocSelector<AiSettingsCubit, AiSettingsState, bool>(
            selector: (state) => state is AiSettingsSaving,
            builder: (context, saving) => AiSettingsSaveButton(
              enabled: !saving && _canSubmit,
              saving: saving,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}
