import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/area.dart';
import '../repositories/areas_repository.dart';

class ListActiveAreas {
  const ListActiveAreas(this._repository);

  final AreasRepository _repository;

  Future<Either<Failure, List<Area>>> call() => _repository.listActive();
}
