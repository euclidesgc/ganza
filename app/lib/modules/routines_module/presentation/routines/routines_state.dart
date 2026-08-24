part of 'routines_cubit.dart';

sealed class RoutinesState extends Equatable {
  const RoutinesState();

  @override
  List<Object?> get props => [];
}

final class RoutinesLoading extends RoutinesState {
  const RoutinesLoading();
}

final class RoutinesReady extends RoutinesState {
  const RoutinesReady(this.occurrences, {this.busyIds = const {}});

  final List<RoutineOccurrence> occurrences;
  final Set<String> busyIds;

  RoutinesReady copyWith({
    List<RoutineOccurrence>? occurrences,
    Set<String>? busyIds,
  }) {
    return RoutinesReady(
      occurrences ?? this.occurrences,
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [occurrences, busyIds];
}

final class RoutinesFailed extends RoutinesState {
  const RoutinesFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
