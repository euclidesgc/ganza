import 'package:equatable/equatable.dart';

class AiCredential extends Equatable {
  const AiCredential({
    required this.id,
    required this.providerKindId,
    required this.model,
    required this.keyLast4,
    required this.isActive,
  });

  final String id;
  final String providerKindId;
  final String model;
  final String keyLast4;
  final bool isActive;

  AiCredential copyWith({
    String? id,
    String? providerKindId,
    String? model,
    String? keyLast4,
    bool? isActive,
  }) {
    return AiCredential(
      id: id ?? this.id,
      providerKindId: providerKindId ?? this.providerKindId,
      model: model ?? this.model,
      keyLast4: keyLast4 ?? this.keyLast4,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [id, providerKindId, model, keyLast4, isActive];
}
