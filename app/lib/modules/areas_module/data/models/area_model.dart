import 'package:fpdart/fpdart.dart';
import 'package:zard/zard.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/area.dart';

/// A resposta do PostgREST muda quando a migration muda. Validar aqui é o que
/// impede uma coluna renomeada de virar `null` silencioso três telas adiante.
abstract final class AreaModel {
  static final _schema = z.map({
    'id': z.string(),
    'slug': z.string(),
    'name': z.string(),
    'position': z.int(),
    'is_system': z.bool(),
    'icon': z.string().optional(),
    'color': z.string().optional(),
  });

  static Either<Failure, Area> fromMap(Map<String, dynamic> map) {
    final result = _schema.safeParse(_withoutNulls(map));
    if (!result.success || result.data == null) {
      return const Left(ValidationFailure('Área em formato inesperado.'));
    }

    final data = result.data!;
    return Right(
      Area(
        id: data['id'] as String,
        slug: data['slug'] as String,
        name: data['name'] as String,
        position: data['position'] as int,
        isSystem: data['is_system'] as bool,
        icon: data['icon'] as String?,
        color: data['color'] as String?,
      ),
    );
  }

  /// O `.nullable()` do zard 0.0.26 não aceita `null` de fato — só `.optional()`
  /// (chave ausente) passa. E o PostgREST manda a coluna nula explicitamente.
  /// Converter nulo em ausência é o que reconcilia os dois sem afrouxar a
  /// validação dos campos obrigatórios, que continuam falhando se sumirem.
  static Map<String, dynamic> _withoutNulls(Map<String, dynamic> map) => {
    for (final entry in map.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}
