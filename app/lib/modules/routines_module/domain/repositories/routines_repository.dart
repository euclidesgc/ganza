import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/routine_occurrence.dart';

abstract interface class RoutinesRepository {
  Future<Either<Failure, List<RoutineOccurrence>>> listPending();

  Future<Either<Failure, Unit>> resolve(
    String occurrenceId,
    String action, {
    String? dueDate,
  });
}
