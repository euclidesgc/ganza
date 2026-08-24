import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/chat_module/domain/entities/chat_proposal.dart';
import 'package:ganza/modules/chat_module/domain/usecases/cancel_proposal.dart';
import 'package:ganza/modules/chat_module/domain/usecases/confirm_proposal.dart';
import 'package:ganza/modules/chat_module/domain/usecases/ingest_message.dart';
import 'package:ganza/modules/chat_module/domain/usecases/list_pending_proposals.dart';
import 'package:ganza/modules/chat_module/presentation/chat/chat_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockIngestMessage extends Mock implements IngestMessage {}

class MockListPendingProposals extends Mock implements ListPendingProposals {}

class MockConfirmProposal extends Mock implements ConfirmProposal {}

class MockCancelProposal extends Mock implements CancelProposal {}

void main() {
  late MockIngestMessage ingestMessage;
  late MockListPendingProposals listPending;
  late MockConfirmProposal confirm;
  late MockCancelProposal cancel;

  final proposal = ChatProposal(
    id: 'p1',
    kind: 'create_transaction',
    payload: {'direction': 'out', 'amount': 4500, 'description': 'almoço'},
    sequence: 1,
    status: 'pending',
  );

  setUp(() {
    ingestMessage = MockIngestMessage();
    listPending = MockListPendingProposals();
    confirm = MockConfirmProposal();
    cancel = MockCancelProposal();
  });

  ChatCubit buildCubit() =>
      ChatCubit(ingestMessage, listPending, confirm, cancel);

  blocTest<ChatCubit, ChatState>(
    'load emite Loading e Ready com os pendentes',
    build: buildCubit,
    act: (cubit) async {
      when(() => listPending.call()).thenAnswer((_) async => Right([proposal]));
      await cubit.load();
    },
    expect: () => [
      const ChatLoading(),
      ChatReady(proposals: [proposal]),
    ],
  );

  blocTest<ChatCubit, ChatState>(
    'send emite Ready em envio e refaz a leitura',
    build: buildCubit,
    act: (cubit) async {
      when(
        () => ingestMessage.call('oi'),
      ).thenAnswer((_) async => const Right(unit));
      when(() => listPending.call()).thenAnswer((_) async => Right([proposal]));
      await cubit.send('oi');
    },
    expect: () => [
      const ChatReady(proposals: [], sending: true),
      ChatReady(proposals: [proposal]),
    ],
  );

  blocTest<ChatCubit, ChatState>(
    'send com falha no ingest emite Failed',
    build: buildCubit,
    act: (cubit) async {
      when(
        () => ingestMessage.call('oi'),
      ).thenAnswer((_) async => const Left(NetworkFailure()));
      await cubit.send('oi');
    },
    expect: () => [
      const ChatReady(proposals: [], sending: true),
      const ChatFailed(NetworkFailure()),
    ],
  );

  blocTest<ChatCubit, ChatState>(
    'confirm marca o card ocupado e o remove ao refazer a leitura',
    build: buildCubit,
    act: (cubit) async {
      var calls = 0;
      when(() => listPending.call()).thenAnswer((_) async {
        calls += 1;
        return calls == 1 ? Right([proposal]) : const Right([]);
      });
      when(() => confirm.call('p1')).thenAnswer((_) async => const Right(unit));
      await cubit.load();
      await cubit.confirm('p1');
    },
    expect: () => [
      const ChatLoading(),
      ChatReady(proposals: [proposal]),
      ChatReady(proposals: [proposal], busyIds: {'p1'}),
      const ChatReady(proposals: []),
    ],
  );

  blocTest<ChatCubit, ChatState>(
    'cancel marca o card ocupado e o remove ao refazer a leitura',
    build: buildCubit,
    act: (cubit) async {
      var calls = 0;
      when(() => listPending.call()).thenAnswer((_) async {
        calls += 1;
        return calls == 1 ? Right([proposal]) : const Right([]);
      });
      when(() => cancel.call('p1')).thenAnswer((_) async => const Right(unit));
      await cubit.load();
      await cubit.cancel('p1');
    },
    expect: () => [
      const ChatLoading(),
      ChatReady(proposals: [proposal]),
      ChatReady(proposals: [proposal], busyIds: {'p1'}),
      const ChatReady(proposals: []),
    ],
  );
}
