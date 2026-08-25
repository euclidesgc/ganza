import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/audio_recording.dart';

abstract interface class ChatAudioRecorder {
  Future<Either<Failure, Unit>> start();

  Future<Either<Failure, AudioRecording>> stop();

  Future<Either<Failure, Unit>> cancel();
}
