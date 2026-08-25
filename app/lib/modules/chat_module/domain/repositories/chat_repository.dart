import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/audio_recording.dart';
import '../entities/chat_proposal.dart';

abstract interface class ChatRepository {
  Future<Either<Failure, Unit>> ingest(String content);

  Future<Either<Failure, String>> transcribe(AudioRecording recording);

  Future<Either<Failure, List<ChatProposal>>> listPending();

  Future<Either<Failure, Unit>> confirm(String proposalId);

  Future<Either<Failure, Unit>> cancel(String proposalId);
}
