import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/chat_module/domain/repositories/chat_repository.dart';
import 'package:ganza/modules/chat_module/domain/usecases/ingest_message.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late MockChatRepository repository;
  late IngestMessage useCase;

  setUp(() {
    repository = MockChatRepository();
    useCase = IngestMessage(repository);
  });

  test('devolve Right delegando ao repositório', () async {
    when(
      () => repository.ingest('oi'),
    ).thenAnswer((_) async => const Right(unit));

    final result = await useCase('oi');

    result.fold(
      (failure) => fail('esperava Right, veio $failure'),
      (_) => expect(true, isTrue),
    );
    verify(() => repository.ingest('oi')).called(1);
  });

  test('propaga o Left do repositório na falha', () async {
    const failure = NetworkFailure();
    when(
      () => repository.ingest('oi'),
    ).thenAnswer((_) async => const Left(failure));

    final result = await useCase('oi');

    result.fold(
      (value) => expect(value, failure),
      (_) => fail('esperava Left'),
    );
  });
}
