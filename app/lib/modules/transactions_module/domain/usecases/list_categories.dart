import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/category.dart';
import '../repositories/categories_repository.dart';

class ListCategories {
  const ListCategories(this._repository);

  final CategoriesRepository _repository;

  Future<Either<Failure, List<Category>>> call() => _repository.list();
}
