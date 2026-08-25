import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/chat_module/domain/entities/chat_proposal.dart';
import 'package:ganza/modules/chat_module/domain/entities/audio_recording.dart';
import 'package:ganza/modules/chat_module/domain/usecases/cancel_audio_recording.dart';
import 'package:ganza/modules/chat_module/domain/usecases/cancel_proposal.dart';
import 'package:ganza/modules/chat_module/domain/usecases/confirm_proposal.dart';
import 'package:ganza/modules/chat_module/domain/usecases/ingest_message.dart';
import 'package:ganza/modules/chat_module/domain/usecases/list_pending_proposals.dart';
import 'package:ganza/modules/chat_module/domain/usecases/start_audio_recording.dart';
import 'package:ganza/modules/chat_module/domain/usecases/stop_audio_recording.dart';
import 'package:ganza/modules/chat_module/domain/usecases/transcribe_audio.dart';
import 'package:ganza/modules/chat_module/presentation/chat/chat_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockIngestMessage extends Mock implements IngestMessage {}

class MockListPendingProposals extends Mock implements ListPendingProposals {}

class MockConfirmProposal extends Mock implements ConfirmProposal {}

class MockCancelProposal extends Mock implements CancelProposal {}

class MockStartAudioRecording extends Mock implements StartAudioRecording {}

class MockStopAudioRecording extends Mock implements StopAudioRecording {}

class MockCancelAudioRecording extends Mock implements CancelAudioRecording {}

class MockTranscribeAudio extends Mock implements TranscribeAudio {}

void main() {
  late MockIngestMessage ingestMessage;
  late MockListPendingProposals listPending;
  late MockConfirmProposal confirm;
  late MockCancelProposal cancel;
  late MockStartAudioRecording startAudioRecording;
  late MockStopAudioRecording stopAudioRecording;
  late MockCancelAudioRecording cancelAudioRecording;
  late MockTranscribeAudio transcribeAudio;

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
    startAudioRecording = MockStartAudioRecording();
    stopAudioRecording = MockStopAudioRecording();
    cancelAudioRecording = MockCancelAudioRecording();
    transcribeAudio = MockTranscribeAudio();
  });

  ChatCubit buildCubit() => ChatCubit(
    ingestMessage,
    listPending,
    confirm,
    cancel,
    startAudioRecording,
    stopAudioRecording,
    cancelAudioRecording,
    transcribeAudio,
  );

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
    'áudio transcrito passa pelo mesmo ingest e recarrega os cards',
    build: buildCubit,
    seed: () => const ChatReady(proposals: []),
    act: (cubit) async {
      final recording = AudioRecording(
        bytes: Uint8List.fromList([1, 2]),
        mimeType: 'audio/wav',
      );
      when(
        () => startAudioRecording.call(),
      ).thenAnswer((_) async => const Right(unit));
      when(
        () => stopAudioRecording.call(),
      ).thenAnswer((_) async => Right(recording));
      when(
        () => transcribeAudio.call(recording),
      ).thenAnswer((_) async => const Right('gastei 45 no almoço'));
      when(
        () => ingestMessage.call('gastei 45 no almoço'),
      ).thenAnswer((_) async => const Right(unit));
      when(() => listPending.call()).thenAnswer((_) async => Right([proposal]));

      await cubit.startAudioRecording();
      await cubit.stopAudioRecording();
    },
    expect: () => [
      const ChatReady(proposals: [], audioStatus: ChatAudioStatus.recording),
      const ChatReady(proposals: [], audioStatus: ChatAudioStatus.transcribing),
      ChatReady(proposals: [proposal]),
    ],
  );

  blocTest<ChatCubit, ChatState>(
    'transcrição vazia mantém os cards e informa que não entendeu o áudio',
    build: buildCubit,
    seed: () => const ChatReady(proposals: []),
    act: (cubit) async {
      final recording = AudioRecording(
        bytes: Uint8List.fromList([1, 2]),
        mimeType: 'audio/wav',
      );
      when(
        () => startAudioRecording.call(),
      ).thenAnswer((_) async => const Right(unit));
      when(
        () => stopAudioRecording.call(),
      ).thenAnswer((_) async => Right(recording));
      when(
        () => transcribeAudio.call(recording),
      ).thenAnswer((_) async => const Right('  '));

      await cubit.startAudioRecording();
      await cubit.stopAudioRecording();
    },
    expect: () => [
      const ChatReady(proposals: [], audioStatus: ChatAudioStatus.recording),
      const ChatReady(proposals: [], audioStatus: ChatAudioStatus.transcribing),
      const ChatReady(
        proposals: [],
        audioFailure: ValidationFailure(
          'Não entendi o áudio. Tente novamente.',
        ),
      ),
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
