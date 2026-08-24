import 'package:equatable/equatable.dart';

class RoutineSummary extends Equatable {
  const RoutineSummary({
    required this.routineId,
    required this.name,
    required this.doneCount,
    required this.resolvedCount,
  });

  final String routineId;
  final String name;
  final int doneCount;
  final int resolvedCount;

  double? get completionRate =>
      resolvedCount == 0 ? null : doneCount / resolvedCount;

  @override
  List<Object?> get props => [routineId, name, doneCount, resolvedCount];
}
