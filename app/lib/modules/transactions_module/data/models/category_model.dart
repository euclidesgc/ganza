import 'package:fpdart/fpdart.dart';
import 'package:zard/zard.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/category.dart';

abstract final class CategoryModel {
  static final _schema = z.map({'id': z.string(), 'name': z.string()});

  static Either<Failure, Category> fromMap(Map<String, dynamic> map) {
    final result = _schema.safeParse(map);
    if (!result.success || result.data == null) {
      return const Left(ValidationFailure('Categoria em formato inesperado.'));
    }

    return Right(
      Category(
        id: result.data!['id'] as String,
        name: result.data!['name'] as String,
      ),
    );
  }
}
