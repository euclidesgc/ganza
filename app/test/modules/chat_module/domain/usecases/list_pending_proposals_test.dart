import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/chat_module/domain/entities/chat_proposal.dart';
import 'package:ganza/modules/chat_module/domain/repositories/chat_repository.dart';
import 'package:ganza/modules/chat_module/domain/usecases/list_pending_proposals.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late MockChatRepository repository;
  late ListPendingProposals useCase;

  final proposal = ChatProposal(
    id: 'p1',
    kind: 'create_transaction',
    payload: {'direction': 'out', 'amount': 4500, 'description': 'almoço'},
    sequence: 1,
    status: 'pending',
  );

  setUp(() {
    repository = MockChatRepository();
    useCase = ListPendingProposals(repository);
  });

  test('devolve Right com os pendentes do repositório', () async {
    when(
      () => repository.listPending(),
    ).thenAnswer((_) async => Right([proposal]));

    final result = await useCase();

    result.fold(
      (failure) => fail('esperava Right, veio $failure'),
      (list) => expect(list, [proposal]),
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
