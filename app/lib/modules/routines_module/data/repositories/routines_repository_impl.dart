import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_from_exception.dart';
import '../../domain/entities/routine_occurrence.dart';
import '../../domain/entities/routine_summary.dart';
import '../../domain/repositories/routines_repository.dart';
import '../models/routine_occurrence_model.dart';
import '../models/routine_summary_model.dart';

class RoutinesRepositoryImpl implements RoutinesRepository {
  const RoutinesRepositoryImpl(this._client);

  final SupabaseClient _client;

  /// Sem filtro por usuário na query: quem decide o que este usuário enxerga é
  /// a RLS (a ocorrência herda o dono pela FK até `routines.user_id`).
  @override
  Future<Either<Failure, List<RoutineOccurrence>>> listPending() async {
    try {
      final rows = await _client
          .from('routine_occurrences')
          .select('id, routine_id, sequence, due_date, status, routines(name)')
          .inFilter('status', ['pending', 'postponed'])
          .order('due_date');

      final occurrences = <RoutineOccurrence>[];
      for (final row in rows) {
        final parsed = RoutineOccurrenceModel.fromMap(row);
        if (parsed.isLeft()) {
          return parsed.map((occurrence) => <RoutineOccurrence>[occurrence]);
        }
        occurrences.add(
          parsed.getOrElse((_) => throw StateError('inalcançável')),
        );
      }
      return Right(occurrences);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  @override
  Future<Either<Failure, List<RoutineSummary>>> listSummaries() async {
    try {
      final rows = await _client
          .from('routine_summaries')
          .select('routine_id, name, done_count, resolved_count');

      final summaries = <RoutineSummary>[];
      for (final row in rows) {
        final parsed = RoutineSummaryModel.fromMap(row);
        if (parsed.isLeft()) {
          return parsed.map((summary) => <RoutineSummary>[summary]);
        }
        summaries.add(
          parsed.getOrElse((_) => throw StateError('inalcançável')),
        );
      }
      return Right(summaries);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> resolve(
    String occurrenceId,
    String action, {
    String? dueDate,
  }) async {
    try {
      final body = <String, dynamic>{
        'occurrence_id': occurrenceId,
        'action': action,
      };
      if (dueDate != null) body['due_date'] = dueDate;
      await _client.functions.invoke('routine-occurrences', body: body);
      return const Right(unit);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }
}
