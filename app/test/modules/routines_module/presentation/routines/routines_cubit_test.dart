import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/routines_module/domain/entities/occurrence_status.dart';
import 'package:ganza/modules/routines_module/domain/entities/routine_occurrence.dart';
import 'package:ganza/modules/routines_module/domain/usecases/list_pending_occurrences.dart';
import 'package:ganza/modules/routines_module/domain/usecases/list_routine_summaries.dart';
import 'package:ganza/modules/routines_module/domain/usecases/resolve_occurrence.dart';
import 'package:ganza/modules/routines_module/presentation/routines/routines_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockListPendingOccurrences extends Mock
    implements ListPendingOccurrences {}

class MockListRoutineSummaries extends Mock implements ListRoutineSummaries {}

class MockResolveOccurrence extends Mock implements ResolveOccurrence {}

void main() {
  late MockListPendingOccurrences listPending;
  late MockListRoutineSummaries listSummaries;
  late MockResolveOccurrence resolveOccurrence;

  final occurrence = RoutineOccurrence(
    id: 'o1',
    routineId: 'r1',
    routineName: 'Banho no cachorro',
    sequence: 1,
    dueDate: DateTime(2026, 8, 24),
    status: OccurrenceStatus.pending,
  );

  setUp(() {
    listPending = MockListPendingOccurrences();
    listSummaries = MockListRoutineSummaries();
    resolveOccurrence = MockResolveOccurrence();
    when(() => listSummaries.call()).thenAnswer((_) async => const Right([]));
  });

  RoutinesCubit buildCubit() =>
      RoutinesCubit(listPending, listSummaries, resolveOccurrence);

  blocTest<RoutinesCubit, RoutinesState>(
    'load emite Loading e Ready com as pendentes',
    build: buildCubit,
    act: (cubit) async {
      when(
        () => listPending.call(),
      ).thenAnswer((_) async => Right([occurrence]));
      await cubit.load();
    },
    expect: () => [
      const RoutinesLoading(),
      RoutinesReady([occurrence]),
    ],
  );

  blocTest<RoutinesCubit, RoutinesState>(
    'load com lista vazia emite Ready vazio',
    build: buildCubit,
    act: (cubit) async {
      when(() => listPending.call()).thenAnswer((_) async => const Right([]));
      await cubit.load();
    },
    expect: () => [const RoutinesLoading(), const RoutinesReady([])],
  );

  blocTest<RoutinesCubit, RoutinesState>(
    'load com falha emite Failed',
    build: buildCubit,
    act: (cubit) async {
      when(
        () => listPending.call(),
      ).thenAnswer((_) async => const Left(NetworkFailure()));
      await cubit.load();
    },
    expect: () => [
      const RoutinesLoading(),
      const RoutinesFailed(NetworkFailure()),
    ],
  );

  blocTest<RoutinesCubit, RoutinesState>(
    'resolve marca ocupado e refaz a leitura sem o id',
    build: buildCubit,
    act: (cubit) async {
      var calls = 0;
      when(() => listPending.call()).thenAnswer((_) async {
        calls += 1;
        return calls == 1 ? Right([occurrence]) : const Right([]);
      });
      when(
        () => resolveOccurrence.call('o1', 'done'),
      ).thenAnswer((_) async => const Right(unit));
      await cubit.load();
      await cubit.resolve('o1', 'done');
    },
    verify: (_) {
      verify(() => resolveOccurrence.call('o1', 'done')).called(1);
    },
    expect: () => [
      const RoutinesLoading(),
      RoutinesReady([occurrence]),
      RoutinesReady([occurrence], busyIds: {'o1'}),
      const RoutinesLoading(),
      const RoutinesReady([]),
    ],
  );
}
