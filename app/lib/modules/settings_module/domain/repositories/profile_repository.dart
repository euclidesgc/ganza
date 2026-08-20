import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<Either<Failure, UserProfile>> getUserProfile();

  Future<Either<Failure, UserProfile>> updateDisplayName({
    required String displayName,
  });
}
