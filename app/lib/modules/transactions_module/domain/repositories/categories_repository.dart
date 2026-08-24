import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/category.dart';

abstract interface class CategoriesRepository {
  Future<Either<Failure, List<Category>>> list();
}
