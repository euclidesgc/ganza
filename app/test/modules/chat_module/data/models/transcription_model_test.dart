import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/chat_module/data/models/transcription_model.dart';

void main() {
  test('lê o transcript válido da resposta da Edge Function', () {
    final result = TranscriptionModel.transcriptFromMap({
      'transcript': 'gastei 45 no almoço',
      'message_id': 'm1',
    });

    result.fold(
      (failure) => fail('esperava Right, veio $failure'),
      (transcript) => expect(transcript, 'gastei 45 no almoço'),
    );
  });

  test('rejeita resposta sem transcript', () {
    final result = TranscriptionModel.transcriptFromMap({'message_id': 'm1'});

    result.fold(
      (failure) => expect(
        failure,
        const ValidationFailure(
          'Resposta de transcrição em formato inesperado.',
        ),
      ),
      (_) => fail('esperava Left'),
    );
  });
}
