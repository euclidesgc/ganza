import 'package:fpdart/fpdart.dart';
import 'package:zard/zard.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/ai_provider_kind.dart';

abstract final class AiProviderKindModel {
  static final _schema = z.map({
    'id': z.string(),
    'slug': z.string(),
    'name': z.string(),
  });

  static Either<Failure, AiProviderKind> fromMap(Map<String, dynamic> map) {
    final result = _schema.safeParse(map);
    if (!result.success || result.data == null) {
      return const Left(
        ValidationFailure('Provedor de IA em formato inesperado.'),
      );
    }

    final data = result.data!;
    return Right(
      AiProviderKind(
        id: data['id'] as String,
        slug: data['slug'] as String,
        label: data['name'] as String,
      ),
    );
  }
}
