import 'package:equatable/equatable.dart';

import 'occurrence_status.dart';

class RoutineOccurrence extends Equatable {
  const RoutineOccurrence({
    required this.id,
    required this.routineId,
    required this.routineName,
    required this.sequence,
    required this.dueDate,
    required this.status,
  });

  final String id;
  final String routineId;
  final String routineName;
  final int sequence;
  final DateTime dueDate;
  final OccurrenceStatus status;

  bool isOverdueOn(DateTime today) {
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final day = DateTime(today.year, today.month, today.day);
    return status == OccurrenceStatus.pending && due.isBefore(day);
  }

  @override
  List<Object?> get props => [
    id,
    routineId,
    routineName,
    sequence,
    dueDate,
    status,
  ];
}
