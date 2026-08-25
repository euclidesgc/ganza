import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/chat_module/data/repositories/chat_repository_impl.dart';
import 'package:ganza/modules/chat_module/domain/entities/audio_recording.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

void main() {
  late MockSupabaseClient client;
  late MockFunctionsClient functions;
  late ChatRepositoryImpl repository;
  late AudioRecording recording;

  setUp(() {
    client = MockSupabaseClient();
    functions = MockFunctionsClient();
    repository = ChatRepositoryImpl(client);
    recording = AudioRecording(
      bytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'audio/wav',
    );
    when(() => client.functions).thenReturn(functions);
  });

  test('envia os bytes em base64 e o MIME para transcribe', () async {
    when(
      () => functions.invoke(
        'transcribe',
        body: {'audio_base64': 'AQID', 'mime_type': 'audio/wav'},
      ),
    ).thenAnswer(
      (_) async => const FunctionResponse(
        status: 200,
        data: {'transcript': 'gastei 45 no almoço', 'message_id': 'm1'},
      ),
    );

    final result = await repository.transcribe(recording);

    result.fold(
      (failure) => fail('esperava Right, veio $failure'),
      (transcript) => expect(transcript, 'gastei 45 no almoço'),
    );
    verify(
      () => functions.invoke(
        'transcribe',
        body: {'audio_base64': 'AQID', 'mime_type': 'audio/wav'},
      ),
    ).called(1);
  });

  test('mapeia áudio sem fala da Edge Function', () async {
    when(
      () => functions.invoke('transcribe', body: any(named: 'body')),
    ).thenThrow(
      const FunctionsHttpException(
        status: 422,
        details: {
          'error': {'code': 'audio_not_understood'},
        },
      ),
    );

    final result = await repository.transcribe(recording);

    expect(
      result,
      const Left<Failure, String>(
        ValidationFailure('Não entendi o áudio. Tente novamente.'),
      ),
    );
  });

  test('mapeia limite de áudio da Edge Function', () async {
    when(
      () => functions.invoke('transcribe', body: any(named: 'body')),
    ).thenThrow(
      const FunctionsHttpException(
        status: 413,
        details: {
          'error': {'code': 'audio_too_large'},
        },
      ),
    );

    final result = await repository.transcribe(recording);

    expect(
      result,
      const Left<Failure, String>(
        ValidationFailure(
          'O áudio é grande demais. Grave uma mensagem mais curta.',
        ),
      ),
    );
  });
}
