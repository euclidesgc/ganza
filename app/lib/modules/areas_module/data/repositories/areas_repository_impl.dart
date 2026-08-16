import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_from_exception.dart';
import '../../domain/entities/area.dart';
import '../../domain/repositories/areas_repository.dart';
import '../models/area_model.dart';

class AreasRepositoryImpl implements AreasRepository {
  const AreasRepositoryImpl(this._client);

  final SupabaseClient _client;

  /// Sem filtro por usuário na query: quem decide o que este usuário enxerga é
  /// a RLS. Replicar a regra aqui daria a impressão de proteção e criaria dois
  /// lugares para errar.
  @override
  Future<Either<Failure, List<Area>>> listActive() async {
    try {
      final rows = await _client
          .from('areas')
          .select('id, slug, name, position, is_system, icon, color')
          .isFilter('archived_at', null)
          .order('position');

      final areas = <Area>[];
      for (final row in rows) {
        final parsed = AreaModel.fromMap(row);
        if (parsed.isLeft()) {
          return parsed.map((area) => <Area>[area]);
        }
        areas.add(parsed.getOrElse((_) => throw StateError('inalcançável')));
      }
      return Right(areas);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }
}
