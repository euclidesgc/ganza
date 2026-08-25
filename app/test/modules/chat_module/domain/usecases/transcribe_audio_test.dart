import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/chat_module/domain/entities/audio_recording.dart';
import 'package:ganza/modules/chat_module/domain/repositories/chat_repository.dart';
import 'package:ganza/modules/chat_module/domain/usecases/transcribe_audio.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late MockChatRepository repository;
  late TranscribeAudio useCase;
  late AudioRecording recording;

  setUp(() {
    repository = MockChatRepository();
    useCase = TranscribeAudio(repository);
    recording = AudioRecording(
      bytes: Uint8List.fromList([1, 2]),
      mimeType: 'audio/wav',
    );
  });

  test('delegar a transcrição devolve o texto', () async {
    when(
      () => repository.transcribe(recording),
    ).thenAnswer((_) async => const Right('gastei 45 no almoço'));

    final result = await useCase(recording);

    expect(result, const Right<Failure, String>('gastei 45 no almoço'));
    verify(() => repository.transcribe(recording)).called(1);
  });

  test('propaga falha de transcrição', () async {
    const failure = ValidationFailure('Não entendi o áudio. Tente novamente.');
    when(
      () => repository.transcribe(recording),
    ).thenAnswer((_) async => const Left(failure));

    final result = await useCase(recording);

    expect(result, const Left<Failure, String>(failure));
  });
}
