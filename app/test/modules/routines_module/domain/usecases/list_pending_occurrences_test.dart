import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/routines_module/domain/entities/occurrence_status.dart';
import 'package:ganza/modules/routines_module/domain/entities/routine_occurrence.dart';
import 'package:ganza/modules/routines_module/domain/repositories/routines_repository.dart';
import 'package:ganza/modules/routines_module/domain/usecases/list_pending_occurrences.dart';
import 'package:mocktail/mocktail.dart';

class MockRoutinesRepository extends Mock implements RoutinesRepository {}

void main() {
  late MockRoutinesRepository repository;
  late ListPendingOccurrences useCase;

  final occurrence = RoutineOccurrence(
    id: 'o1',
    routineId: 'r1',
    routineName: 'Banho no cachorro',
    sequence: 1,
    dueDate: DateTime(2026, 8, 24),
    status: OccurrenceStatus.pending,
  );

  setUp(() {
    repository = MockRoutinesRepository();
    useCase = ListPendingOccurrences(repository);
  });

  test('devolve Right com as pendentes do repositório', () async {
    when(
      () => repository.listPending(),
    ).thenAnswer((_) async => Right([occurrence]));

    final result = await useCase();

    result.fold(
      (failure) => fail('esperava Right, veio $failure'),
      (list) => expect(list, [occurrence]),
    );
  });

  test('propaga o Left do repositório na falha', () async {
    const failure = NetworkFailure();
    when(
      () => repository.listPending(),
    ).thenAnswer((_) async => const Left(failure));

    final result = await useCase();

    result.fold(
      (value) => expect(value, failure),
      (_) => fail('esperava Left'),
    );
  });
}
