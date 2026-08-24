import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/transactions_module/domain/repositories/transactions_repository.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/categorize_transaction.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionsRepository extends Mock
    implements TransactionsRepository {}

void main() {
  late MockTransactionsRepository repository;
  late CategorizeTransaction useCase;

  setUp(() {
    repository = MockTransactionsRepository();
    useCase = CategorizeTransaction(repository);
  });

  test('devolve Right delegando ao repositório', () async {
    when(
      () => repository.categorize('t1', 'c1'),
    ).thenAnswer((_) async => const Right(unit));

    final result = await useCase('t1', 'c1');

    result.fold(
      (failure) => fail('esperava Right, veio $failure'),
      (_) => expect(true, isTrue),
    );
    verify(() => repository.categorize('t1', 'c1')).called(1);
  });

  test('propaga o Left do repositório na falha', () async {
    const failure = NotFoundFailure();
    when(
      () => repository.categorize('t1', 'c1'),
    ).thenAnswer((_) async => const Left(failure));

    final result = await useCase('t1', 'c1');

    result.fold(
      (value) => expect(value, failure),
      (_) => fail('esperava Left'),
    );
  });
}
