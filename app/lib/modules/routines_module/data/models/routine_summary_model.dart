import 'package:fpdart/fpdart.dart';
import 'package:zard/zard.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/routine_summary.dart';

abstract final class RoutineSummaryModel {
  static final _schema = z.map({
    'routine_id': z.string(),
    'name': z.string(),
    'done_count': z.int(),
    'resolved_count': z.int(),
  });

  static Either<Failure, RoutineSummary> fromMap(Map<String, dynamic> map) {
    final result = _schema.safeParse(map);
    if (!result.success || result.data == null) {
      return const Left(ValidationFailure('Resumo em formato inesperado.'));
    }

    return Right(
      RoutineSummary(
        routineId: result.data!['routine_id'] as String,
        name: result.data!['name'] as String,
        doneCount: result.data!['done_count'] as int,
        resolvedCount: result.data!['resolved_count'] as int,
      ),
    );
  }
}
