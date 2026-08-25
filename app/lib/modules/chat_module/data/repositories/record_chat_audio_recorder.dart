import 'dart:async';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:record/record.dart' as record;

import '../../../../core/error/failure.dart';
import '../../domain/entities/audio_recording.dart';
import '../../domain/repositories/chat_audio_recorder.dart';

class RecordChatAudioRecorder implements ChatAudioRecorder {
  RecordChatAudioRecorder(this._recorder);

  final record.AudioRecorder _recorder;
  final BytesBuilder _bytes = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;
  Failure? _streamFailure;

  @override
  Future<Either<Failure, Unit>> start() async {
    try {
      if (await _recorder.isRecording()) {
        return const Left(
          ValidationFailure('Já existe uma gravação em andamento.'),
        );
      }
      if (!await _recorder.hasPermission()) {
        return const Left(
          PermissionFailure(
            'Permita o acesso ao microfone para gravar um áudio.',
          ),
        );
      }

      _bytes.clear();
      _streamFailure = null;
      final stream = await _recorder.startStream(
        const record.RecordConfig(
          encoder: record.AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _subscription = stream.listen(
        _bytes.add,
        onError: (Object error, StackTrace stackTrace) => _streamFailure =
            const UnexpectedFailure('Não foi possível gravar o áudio.'),
      );
      return const Right(unit);
    } catch (error) {
      return const Left(
        UnexpectedFailure('Não foi possível iniciar a gravação.'),
      );
    }
  }

  @override
  Future<Either<Failure, AudioRecording>> stop() async {
    try {
      await _recorder.stop();
      await _subscription?.cancel();
      _subscription = null;
      if (_streamFailure case final failure?) return Left(failure);
      final bytes = _bytes.toBytes();
      if (bytes.isEmpty) {
        return const Left(
          ValidationFailure('Não entendi o áudio. Tente novamente.'),
        );
      }
      return Right(AudioRecording(bytes: _wav(bytes), mimeType: 'audio/wav'));
    } catch (error) {
      return const Left(
        UnexpectedFailure('Não foi possível finalizar a gravação.'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> cancel() async {
    try {
      await _recorder.cancel();
      await _subscription?.cancel();
      _subscription = null;
      _bytes.clear();
      _streamFailure = null;
      return const Right(unit);
    } catch (error) {
      return const Left(
        UnexpectedFailure('Não foi possível cancelar a gravação.'),
      );
    }
  }

  Uint8List _wav(Uint8List pcm) {
    final output = Uint8List(44 + pcm.length);
    final header = ByteData.sublistView(output);
    output.setRange(0, 4, 'RIFF'.codeUnits);
    header.setUint32(4, pcm.length + 36, Endian.little);
    output.setRange(8, 12, 'WAVE'.codeUnits);
    output.setRange(12, 16, 'fmt '.codeUnits);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, 16000, Endian.little);
    header.setUint32(28, 32000, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    output.setRange(36, 40, 'data'.codeUnits);
    header.setUint32(40, pcm.length, Endian.little);
    output.setRange(44, output.length, pcm);
    return output;
  }
}
