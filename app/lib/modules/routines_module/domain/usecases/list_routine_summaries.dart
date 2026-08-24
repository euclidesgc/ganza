import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/routine_summary.dart';
import '../repositories/routines_repository.dart';

class ListRoutineSummaries {
  const ListRoutineSummaries(this._repository);

  final RoutinesRepository _repository;

  Future<Either<Failure, List<RoutineSummary>>> call() =>
      _repository.listSummaries();
}
