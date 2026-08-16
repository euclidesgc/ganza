import 'package:equatable/equatable.dart';

class Area extends Equatable {
  const Area({
    required this.id,
    required this.slug,
    required this.name,
    required this.position,
    required this.isSystem,
    this.icon,
    this.color,
  });

  final String id;
  final String slug;
  final String name;
  final int position;
  final bool isSystem;
  final String? icon;
  final String? color;

  @override
  List<Object?> get props => [id, slug, name, position, isSystem, icon, color];
}
