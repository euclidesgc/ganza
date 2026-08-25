import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/chat_module/domain/entities/audio_recording.dart';
import 'package:ganza/modules/chat_module/domain/repositories/chat_audio_recorder.dart';
import 'package:ganza/modules/chat_module/domain/usecases/cancel_audio_recording.dart';
import 'package:ganza/modules/chat_module/domain/usecases/start_audio_recording.dart';
import 'package:ganza/modules/chat_module/domain/usecases/stop_audio_recording.dart';
import 'package:mocktail/mocktail.dart';

class MockChatAudioRecorder extends Mock implements ChatAudioRecorder {}

void main() {
  late MockChatAudioRecorder recorder;

  setUp(() => recorder = MockChatAudioRecorder());

  test('StartAudioRecording delega ao gravador', () async {
    when(() => recorder.start()).thenAnswer((_) async => const Right(unit));

    final result = await StartAudioRecording(recorder)();

    expect(result, const Right<Failure, Unit>(unit));
    verify(() => recorder.start()).called(1);
  });

  test('StopAudioRecording devolve o áudio capturado', () async {
    final audio = AudioRecording(
      bytes: Uint8List.fromList([1, 2]),
      mimeType: 'audio/wav',
    );
    when(() => recorder.stop()).thenAnswer((_) async => Right(audio));

    final result = await StopAudioRecording(recorder)();

    expect(result, Right<Failure, AudioRecording>(audio));
    verify(() => recorder.stop()).called(1);
  });

  test('CancelAudioRecording propaga a falha do gravador', () async {
    const failure = PermissionFailure();
    when(() => recorder.cancel()).thenAnswer((_) async => const Left(failure));

    final result = await CancelAudioRecording(recorder)();

    expect(result, const Left<Failure, Unit>(failure));
    verify(() => recorder.cancel()).called(1);
  });
}
