import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/audio_recording.dart';
import '../repositories/chat_repository.dart';

class TranscribeAudio {
  const TranscribeAudio(this._repository);

  final ChatRepository _repository;

  Future<Either<Failure, String>> call(AudioRecording recording) =>
      _repository.transcribe(recording);
}
