import 'package:equatable/equatable.dart';

class AiProviderKind extends Equatable {
  const AiProviderKind({
    required this.id,
    required this.slug,
    required this.label,
  });

  final String id;
  final String slug;
  final String label;

  AiProviderKind copyWith({String? id, String? slug, String? label}) {
    return AiProviderKind(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      label: label ?? this.label,
    );
  }

  @override
  List<Object?> get props => [id, slug, label];
}
