import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/routines_module/data/models/routine_occurrence_model.dart';
import 'package:ganza/modules/routines_module/domain/entities/occurrence_status.dart';

void main() {
  final validMap = <String, dynamic>{
    'id': 'o1',
    'routine_id': 'r1',
    'sequence': 1,
    'due_date': '2026-08-24',
    'status': 'pending',
    'routines': {'name': 'Banho no cachorro'},
  };

  group('RoutineOccurrenceModel.fromMap', () {
    test('linha completa vira a entidade', () {
      final result = RoutineOccurrenceModel.fromMap(validMap);
      result.fold((failure) => fail('esperava Right, veio $failure'), (
        occurrence,
      ) {
        expect(occurrence.id, 'o1');
        expect(occurrence.routineName, 'Banho no cachorro');
        expect(occurrence.status, OccurrenceStatus.pending);
        expect(occurrence.dueDate, DateTime(2026, 8, 24));
      });
    });

    test('sem id devolve Left(ValidationFailure)', () {
      final result = RoutineOccurrenceModel.fromMap(
        {...validMap}..remove('id'),
      );
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('sem due_date devolve Left(ValidationFailure)', () {
      final result = RoutineOccurrenceModel.fromMap(
        {...validMap}..remove('due_date'),
      );
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('status desconhecido devolve Left(ValidationFailure)', () {
      final result = RoutineOccurrenceModel.fromMap({
        ...validMap,
        'status': 'explodida',
      });
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });
}
