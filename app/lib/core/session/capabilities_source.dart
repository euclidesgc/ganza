import 'package:fpdart/fpdart.dart';

import '../error/error.dart';
import 'user_capabilities.dart';

abstract interface class CapabilitiesSource {
  Future<Either<Failure, UserCapabilities>> load();
}
