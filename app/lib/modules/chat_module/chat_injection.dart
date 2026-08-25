import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repositories/chat_repository_impl.dart';
import 'data/repositories/record_chat_audio_recorder.dart';
import 'domain/repositories/chat_audio_recorder.dart';
import 'domain/repositories/chat_repository.dart';
import 'domain/usecases/cancel_audio_recording.dart';
import 'domain/usecases/cancel_proposal.dart';
import 'domain/usecases/confirm_proposal.dart';
import 'domain/usecases/ingest_message.dart';
import 'domain/usecases/list_pending_proposals.dart';
import 'domain/usecases/start_audio_recording.dart';
import 'domain/usecases/stop_audio_recording.dart';
import 'domain/usecases/transcribe_audio.dart';
import 'presentation/chat/chat_cubit.dart';
import 'package:record/record.dart';

void registerChatModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<ChatAudioRecorder>(
      () => RecordChatAudioRecorder(AudioRecorder()),
    )
    ..registerFactory(() => IngestMessage(getIt<ChatRepository>()))
    ..registerFactory(() => ListPendingProposals(getIt<ChatRepository>()))
    ..registerFactory(() => ConfirmProposal(getIt<ChatRepository>()))
    ..registerFactory(() => CancelProposal(getIt<ChatRepository>()))
    ..registerFactory(() => StartAudioRecording(getIt<ChatAudioRecorder>()))
    ..registerFactory(() => StopAudioRecording(getIt<ChatAudioRecorder>()))
    ..registerFactory(() => CancelAudioRecording(getIt<ChatAudioRecorder>()))
    ..registerFactory(() => TranscribeAudio(getIt<ChatRepository>()))
    ..registerFactory(
      () => ChatCubit(
        getIt<IngestMessage>(),
        getIt<ListPendingProposals>(),
        getIt<ConfirmProposal>(),
        getIt<CancelProposal>(),
        getIt<StartAudioRecording>(),
        getIt<StopAudioRecording>(),
        getIt<CancelAudioRecording>(),
        getIt<TranscribeAudio>(),
      ),
    );
}
