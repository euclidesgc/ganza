import 'package:fpdart/fpdart.dart';
import 'package:zard/zard.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/occurrence_status.dart';
import '../../domain/entities/routine_occurrence.dart';

abstract final class RoutineOccurrenceModel {
  static final _schema = z.map({
    'id': z.string(),
    'routine_id': z.string(),
    'sequence': z.int(),
    'due_date': z.string(),
    'status': z.string(),
    'routines': z.map({'name': z.string()}),
  });

  static Either<Failure, RoutineOccurrence> fromMap(Map<String, dynamic> map) {
    final result = _schema.safeParse(map);
    if (!result.success || result.data == null) {
      return const Left(ValidationFailure('Ocorrência em formato inesperado.'));
    }

    final data = result.data!;
    final status = OccurrenceStatus.fromWire(data['status'] as String);
    final dueDate = DateTime.tryParse(data['due_date'] as String);
    if (status == null || dueDate == null) {
      return const Left(ValidationFailure('Ocorrência em formato inesperado.'));
    }

    final routines = data['routines'] as Map<String, dynamic>;

    return Right(
      RoutineOccurrence(
        id: data['id'] as String,
        routineId: data['routine_id'] as String,
        routineName: routines['name'] as String,
        sequence: data['sequence'] as int,
        dueDate: dueDate,
        status: status,
      ),
    );
  }
}
