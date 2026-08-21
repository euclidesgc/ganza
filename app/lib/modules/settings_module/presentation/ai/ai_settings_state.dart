part of 'ai_settings_cubit.dart';

sealed class AiSettingsState extends Equatable {
  const AiSettingsState();

  @override
  List<Object?> get props => [];
}

extension AiSettingsStateData on AiSettingsState {
  List<AiProviderKind> get providerKindsOrEmpty => switch (this) {
    AiSettingsReady(:final providerKinds) => providerKinds,
    AiSettingsSaving(:final providerKinds) => providerKinds,
    AiSettingsSaveFailed(:final providerKinds) => providerKinds,
    AiSettingsLoading() || AiSettingsLoadFailed() => const [],
  };

  AiCredential? get credentialOrNull => switch (this) {
    AiSettingsReady(:final credential) => credential,
    AiSettingsSaving(:final credential) => credential,
    AiSettingsSaveFailed(:final credential) => credential,
    AiSettingsLoading() || AiSettingsLoadFailed() => null,
  };
}

final class AiSettingsLoading extends AiSettingsState {
  const AiSettingsLoading();
}

final class AiSettingsLoadFailed extends AiSettingsState {
  const AiSettingsLoadFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class AiSettingsReady extends AiSettingsState {
  const AiSettingsReady({
    required this.providerKinds,
    required this.credential,
  });

  final List<AiProviderKind> providerKinds;
  final AiCredential? credential;

  @override
  List<Object?> get props => [providerKinds, credential];
}

final class AiSettingsSaving extends AiSettingsState {
  const AiSettingsSaving({
    required this.providerKinds,
    required this.credential,
  });

  final List<AiProviderKind> providerKinds;
  final AiCredential? credential;

  @override
  List<Object?> get props => [providerKinds, credential];
}

final class AiSettingsSaveFailed extends AiSettingsState {
  const AiSettingsSaveFailed({
    required this.providerKinds,
    required this.credential,
    required this.failure,
  });

  final List<AiProviderKind> providerKinds;
  final AiCredential? credential;
  final Failure failure;

  @override
  List<Object?> get props => [providerKinds, credential, failure];
}
