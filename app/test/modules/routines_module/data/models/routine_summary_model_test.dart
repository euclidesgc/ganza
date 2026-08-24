import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/routines_module/data/models/routine_summary_model.dart';

void main() {
  final validMap = <String, dynamic>{
    'routine_id': 'r1',
    'name': 'Banho no cachorro',
    'done_count': 2,
    'resolved_count': 3,
  };

  group('RoutineSummaryModel.fromMap', () {
    test('linha completa vira a entidade', () {
      final result = RoutineSummaryModel.fromMap(validMap);
      result.fold((failure) => fail('esperava Right, veio $failure'), (
        summary,
      ) {
        expect(summary.routineId, 'r1');
        expect(summary.doneCount, 2);
        expect(summary.resolvedCount, 3);
        expect(summary.completionRate, closeTo(0.666, 0.001));
      });
    });

    test('sem routine_id devolve Left(ValidationFailure)', () {
      final result = RoutineSummaryModel.fromMap(
        {...validMap}..remove('routine_id'),
      );
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('sem name devolve Left(ValidationFailure)', () {
      final result = RoutineSummaryModel.fromMap({...validMap}..remove('name'));
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('resolved_count zero devolve taxa nula', () {
      final result = RoutineSummaryModel.fromMap({
        ...validMap,
        'done_count': 0,
        'resolved_count': 0,
      });
      result.fold(
        (failure) => fail('esperava Right, veio $failure'),
        (summary) => expect(summary.completionRate, isNull),
      );
    });
  });
}
