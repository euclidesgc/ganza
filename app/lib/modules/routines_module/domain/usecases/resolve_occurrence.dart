import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/routines_repository.dart';

class ResolveOccurrence {
  const ResolveOccurrence(this._repository);

  final RoutinesRepository _repository;

  Future<Either<Failure, Unit>> call(
    String occurrenceId,
    String action, {
    String? dueDate,
  }) => _repository.resolve(occurrenceId, action, dueDate: dueDate);
}
