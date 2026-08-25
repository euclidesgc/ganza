import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/chat_audio_recorder.dart';

class CancelAudioRecording {
  const CancelAudioRecording(this._recorder);

  final ChatAudioRecorder _recorder;

  Future<Either<Failure, Unit>> call() => _recorder.cancel();
}
