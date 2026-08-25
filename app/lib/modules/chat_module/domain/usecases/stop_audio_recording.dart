import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/audio_recording.dart';
import '../repositories/chat_audio_recorder.dart';

class StopAudioRecording {
  const StopAudioRecording(this._recorder);

  final ChatAudioRecorder _recorder;

  Future<Either<Failure, AudioRecording>> call() => _recorder.stop();
}
