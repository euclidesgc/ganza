import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/routine_occurrence.dart';
import '../../domain/usecases/list_pending_occurrences.dart';
import '../../domain/usecases/resolve_occurrence.dart';

part 'routines_state.dart';

class RoutinesCubit extends Cubit<RoutinesState> {
  RoutinesCubit(this._listPending, this._resolveOccurrence)
    : super(const RoutinesLoading());

  final ListPendingOccurrences _listPending;
  final ResolveOccurrence _resolveOccurrence;

  Future<void> load() async {
    emit(const RoutinesLoading());

    final result = await _listPending();
    if (isClosed) return;

    emit(
      result.fold(
        RoutinesFailed.new,
        (occurrences) => RoutinesReady(occurrences),
      ),
    );
  }

  Future<void> resolve(
    String occurrenceId,
    String action, {
    String? dueDate,
  }) async {
    final current = state;
    if (current is! RoutinesReady || current.busyIds.contains(occurrenceId)) {
      return;
    }

    emit(current.copyWith(busyIds: {...current.busyIds, occurrenceId}));

    final result = await _resolveOccurrence(
      occurrenceId,
      action,
      dueDate: dueDate,
    );
    if (isClosed) return;

    await result.fold((_) async {
      final ready = state;
      if (ready is RoutinesReady) {
        final busy = {...ready.busyIds}..remove(occurrenceId);
        emit(ready.copyWith(busyIds: busy));
      }
    }, (_) => load());
  }
}
