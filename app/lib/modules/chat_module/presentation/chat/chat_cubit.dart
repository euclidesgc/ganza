import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/chat_proposal.dart';
import '../../domain/usecases/cancel_proposal.dart';
import '../../domain/usecases/cancel_audio_recording.dart';
import '../../domain/usecases/confirm_proposal.dart';
import '../../domain/usecases/ingest_message.dart';
import '../../domain/usecases/list_pending_proposals.dart';
import '../../domain/usecases/start_audio_recording.dart';
import '../../domain/usecases/stop_audio_recording.dart';
import '../../domain/usecases/transcribe_audio.dart';

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit(
    this._ingestMessage,
    this._listPendingProposals,
    this._confirmProposal,
    this._cancelProposal,
    this._startAudioRecording,
    this._stopAudioRecording,
    this._cancelAudioRecording,
    this._transcribeAudio,
  ) : super(const ChatLoading());

  final IngestMessage _ingestMessage;
  final ListPendingProposals _listPendingProposals;
  final ConfirmProposal _confirmProposal;
  final CancelProposal _cancelProposal;
  final StartAudioRecording _startAudioRecording;
  final StopAudioRecording _stopAudioRecording;
  final CancelAudioRecording _cancelAudioRecording;
  final TranscribeAudio _transcribeAudio;

  Future<void> load() async {
    emit(const ChatLoading());

    final result = await _listPendingProposals();
    if (isClosed) return;

    emit(_fromResult(result));
  }

  Future<void> send(String content) async {
    final proposals = switch (state) {
      ChatReady(proposals: final list) => list,
      _ => const <ChatProposal>[],
    };
    emit(ChatReady(proposals: proposals, sending: true));

    final result = await _ingestMessage(content);
    if (isClosed) return;

    await result.fold((failure) async {
      emit(ChatFailed(failure));
    }, (_) => _refetch());
  }

  Future<void> startAudioRecording() async {
    final current = state;
    if (current is! ChatReady || current.isBusy) return;

    final result = await _startAudioRecording();
    if (isClosed) return;

    result.fold(
      (failure) => emit(
        current.copyWith(audioFailure: failure, clearAudioFailure: false),
      ),
      (_) => emit(
        current.copyWith(
          audioStatus: ChatAudioStatus.recording,
          clearAudioFailure: true,
        ),
      ),
    );
  }

  Future<void> stopAudioRecording() async {
    final current = state;
    if (current is! ChatReady ||
        current.audioStatus != ChatAudioStatus.recording) {
      return;
    }

    emit(
      current.copyWith(
        audioStatus: ChatAudioStatus.transcribing,
        clearAudioFailure: true,
      ),
    );
    final recording = await _stopAudioRecording();
    if (isClosed) return;

    await recording.fold(
      (failure) async => _emitAudioFailure(current, failure),
      (audio) async {
        final transcription = await _transcribeAudio(audio);
        if (isClosed) return;
        await transcription.fold(
          (failure) async => _emitAudioFailure(current, failure),
          (transcript) async {
            if (transcript.trim().isEmpty) {
              _emitAudioFailure(
                current,
                const ValidationFailure(
                  'Não entendi o áudio. Tente novamente.',
                ),
              );
              return;
            }
            final ingestion = await _ingestMessage(transcript.trim());
            if (isClosed) return;
            await ingestion.fold(
              (failure) async => _emitAudioFailure(current, failure),
              (_) => _refetch(),
            );
          },
        );
      },
    );
  }

  Future<void> cancelAudioRecording() async {
    final current = state;
    if (current is! ChatReady ||
        current.audioStatus != ChatAudioStatus.recording) {
      return;
    }

    final result = await _cancelAudioRecording();
    if (isClosed) return;

    result.fold(
      (failure) => _emitAudioFailure(current, failure),
      (_) => emit(
        current.copyWith(
          audioStatus: ChatAudioStatus.idle,
          clearAudioFailure: true,
        ),
      ),
    );
  }

  Future<void> confirm(String proposalId) =>
      _resolve(proposalId, _confirmProposal.call);

  Future<void> cancel(String proposalId) =>
      _resolve(proposalId, _cancelProposal.call);

  Future<void> _resolve(
    String proposalId,
    Future<Either<Failure, Unit>> Function(String) operation,
  ) async {
    final current = state;
    if (current is! ChatReady || current.busyIds.contains(proposalId)) return;

    emit(current.copyWith(busyIds: {...current.busyIds, proposalId}));

    final result = await operation(proposalId);
    if (isClosed) return;

    await result.fold((_) async {
      final ready = state;
      if (ready is ChatReady) {
        final busy = {...ready.busyIds}..remove(proposalId);
        emit(ready.copyWith(busyIds: busy));
      }
    }, (_) => _refetch());
  }

  Future<void> _refetch() async {
    final result = await _listPendingProposals();
    if (isClosed) return;

    emit(_fromResult(result));
  }

  void _emitAudioFailure(ChatReady current, Failure failure) {
    if (isClosed) return;
    emit(
      current.copyWith(
        audioStatus: ChatAudioStatus.idle,
        audioFailure: failure,
      ),
    );
  }

  ChatState _fromResult(Either<Failure, List<ChatProposal>> result) => result
      .fold(ChatFailed.new, (proposals) => ChatReady(proposals: proposals));
}
