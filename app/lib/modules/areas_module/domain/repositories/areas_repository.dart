import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/area.dart';

abstract interface class AreasRepository {
  Future<Either<Failure, List<Area>>> listActive();
}
