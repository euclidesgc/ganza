import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/user_profile.dart';
import '../repositories/profile_repository.dart';

class UpdateDisplayName {
  const UpdateDisplayName(this._repository);

  final ProfileRepository _repository;

  Future<Either<Failure, UserProfile>> call({required String displayName}) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Informe um nome de exibição.')),
      );
    }
    return _repository.updateDisplayName(displayName: trimmed);
  }
}
