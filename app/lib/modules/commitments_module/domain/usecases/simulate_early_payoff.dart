import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/commitment.dart';
import '../entities/payoff_simulation.dart';
import '../repositories/commitments_repository.dart';

class SimulateEarlyPayoff {
  const SimulateEarlyPayoff(this._repository);

  final CommitmentsRepository _repository;

  Future<Either<Failure, PayoffSimulation>> call(Commitment commitment) =>
      _repository.simulateEarlyPayoff(commitment);
}
