import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/user_profile.dart';
import '../repositories/profile_repository.dart';

class GetUserProfile {
  const GetUserProfile(this._repository);

  final ProfileRepository _repository;

  Future<Either<Failure, UserProfile>> call() {
    return _repository.getUserProfile();
  }
}
