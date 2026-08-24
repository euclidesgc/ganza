import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/routine_occurrence.dart';
import '../repositories/routines_repository.dart';

class ListPendingOccurrences {
  const ListPendingOccurrences(this._repository);

  final RoutinesRepository _repository;

  Future<Either<Failure, List<RoutineOccurrence>>> call() =>
      _repository.listPending();
}
