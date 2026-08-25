import 'package:fpdart/fpdart.dart';
import 'package:zard/zard.dart';

import '../../../../core/error/failure.dart';

abstract final class TranscriptionModel {
  static final _schema = z.map({'transcript': z.string()});

  static Either<Failure, String> transcriptFromMap(Map<String, dynamic> map) {
    final result = _schema.safeParse(map);
    if (!result.success || result.data == null) {
      return const Left(
        ValidationFailure('Resposta de transcrição em formato inesperado.'),
      );
    }

    return Right(result.data!['transcript'] as String);
  }
}
