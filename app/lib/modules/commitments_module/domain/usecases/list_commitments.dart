import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/commitment.dart';
import '../repositories/commitments_repository.dart';

class ListCommitments {
  const ListCommitments(this._repository);

  final CommitmentsRepository _repository;

  Future<Either<Failure, List<Commitment>>> call() => _repository.list();
}
