import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/ai_credential.dart';
import '../../domain/entities/ai_provider_kind.dart';
import '../../domain/usecases/get_ai_credential.dart';
import '../../domain/usecases/get_ai_provider_kinds.dart';
import '../../domain/usecases/save_ai_credential.dart';

part 'ai_settings_state.dart';

class AiSettingsCubit extends Cubit<AiSettingsState> {
  AiSettingsCubit(
    this._getProviderKinds,
    this._getCredential,
    this._saveCredential,
  ) : super(const AiSettingsLoading());

  final GetAiProviderKinds _getProviderKinds;
  final GetAiCredential _getCredential;
  final SaveAiCredential _saveCredential;

  Future<void> load() async {
    emit(const AiSettingsLoading());

    final kindsResult = await _getProviderKinds();
    if (isClosed) return;

    final kindsFailure = kindsResult.fold((failure) => failure, (_) => null);
    if (kindsFailure != null) {
      emit(AiSettingsLoadFailed(kindsFailure));
      return;
    }
    final providerKinds = kindsResult.getOrElse((_) => const []);

    final credentialResult = await _getCredential();
    if (isClosed) return;

    emit(
      credentialResult.fold(
        AiSettingsLoadFailed.new,
        (credential) => AiSettingsReady(
          providerKinds: providerKinds,
          credential: credential,
        ),
      ),
    );
  }

  Future<void> save({
    required String providerKindId,
    required String model,
    required String apiKey,
  }) async {
    final providerKinds = state.providerKindsOrEmpty;
    final credential = state.credentialOrNull;

    emit(
      AiSettingsSaving(providerKinds: providerKinds, credential: credential),
    );

    final result = await _saveCredential(
      providerKindId: providerKindId,
      model: model,
      apiKey: apiKey,
    );
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => AiSettingsSaveFailed(
          providerKinds: providerKinds,
          credential: credential,
          failure: failure,
        ),
        (saved) =>
            AiSettingsReady(providerKinds: providerKinds, credential: saved),
      ),
    );
  }
}
