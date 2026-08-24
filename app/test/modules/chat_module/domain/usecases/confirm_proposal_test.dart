import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/chat_module/domain/repositories/chat_repository.dart';
import 'package:ganza/modules/chat_module/domain/usecases/confirm_proposal.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late MockChatRepository repository;
  late ConfirmProposal useCase;

  setUp(() {
    repository = MockChatRepository();
    useCase = ConfirmProposal(repository);
  });

  test('devolve Right delegando ao repositório', () async {
    when(
      () => repository.confirm('p1'),
    ).thenAnswer((_) async => const Right(unit));

    final result = await useCase('p1');

    result.fold(
      (failure) => fail('esperava Right, veio $failure'),
      (_) => expect(true, isTrue),
    );
    verify(() => repository.confirm('p1')).called(1);
  });

  test('propaga o Left do repositório na falha', () async {
    const failure = NotFoundFailure();
    when(
      () => repository.confirm('p1'),
    ).thenAnswer((_) async => const Left(failure));

    final result = await useCase('p1');

    result.fold(
      (value) => expect(value, failure),
      (_) => fail('esperava Left'),
    );
  });
}
