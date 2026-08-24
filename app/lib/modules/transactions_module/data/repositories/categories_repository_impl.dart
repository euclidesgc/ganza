import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_from_exception.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/categories_repository.dart';
import '../models/category_model.dart';

class CategoriesRepositoryImpl implements CategoriesRepository {
  const CategoriesRepositoryImpl(this._client);

  final SupabaseClient _client;

  /// Sem filtro por usuário na query: quem decide o que este usuário enxerga é
  /// a RLS. Replicar a regra aqui daria a impressão de proteção e criaria dois
  /// lugares para errar.
  @override
  Future<Either<Failure, List<Category>>> list() async {
    try {
      final rows = await _client
          .from('categories')
          .select('id, name')
          .order('name');

      final categories = <Category>[];
      for (final row in rows) {
        final parsed = CategoryModel.fromMap(row);
        if (parsed.isLeft()) {
          return parsed.map((category) => <Category>[category]);
        }
        categories.add(
          parsed.getOrElse((_) => throw StateError('inalcançável')),
        );
      }
      return Right(categories);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }
}
