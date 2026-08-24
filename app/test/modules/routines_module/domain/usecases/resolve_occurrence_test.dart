import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/routines_module/domain/repositories/routines_repository.dart';
import 'package:ganza/modules/routines_module/domain/usecases/resolve_occurrence.dart';
import 'package:mocktail/mocktail.dart';

class MockRoutinesRepository extends Mock implements RoutinesRepository {}

void main() {
  late MockRoutinesRepository repository;
  late ResolveOccurrence useCase;

  setUp(() {
    repository = MockRoutinesRepository();
    useCase = ResolveOccurrence(repository);
  });

  test('devolve Right delegando ao repositório', () async {
    when(
      () => repository.resolve('o1', 'done'),
    ).thenAnswer((_) async => const Right(unit));

    final result = await useCase('o1', 'done');

    result.fold(
      (failure) => fail('esperava Right, veio $failure'),
      (_) => expect(true, isTrue),
    );
    verify(() => repository.resolve('o1', 'done')).called(1);
  });

  test('propaga o Left do repositório na falha', () async {
    const failure = NotFoundFailure();
    when(
      () => repository.resolve('o1', 'cancel', dueDate: any(named: 'dueDate')),
    ).thenAnswer((_) async => const Left(failure));

    final result = await useCase('o1', 'cancel', dueDate: '2026-08-26');

    result.fold(
      (value) => expect(value, failure),
      (_) => fail('esperava Left'),
    );
  });
}
