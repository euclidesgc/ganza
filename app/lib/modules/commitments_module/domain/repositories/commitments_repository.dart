import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/commitment.dart';
import '../entities/payoff_simulation.dart';

abstract interface class CommitmentsRepository {
  Future<Either<Failure, List<Commitment>>> list();

  Future<Either<Failure, PayoffSimulation>> simulateEarlyPayoff(
    Commitment commitment,
  );
}
