part of 'commitments_cubit.dart';

sealed class CommitmentsState extends Equatable {
  const CommitmentsState();

  @override
  List<Object?> get props => [];
}

final class CommitmentsLoading extends CommitmentsState {
  const CommitmentsLoading();
}

final class CommitmentsReady extends CommitmentsState {
  const CommitmentsReady(
    this.commitments, {
    this.busyIds = const {},
    this.simulations = const {},
  });

  final List<Commitment> commitments;
  final Set<String> busyIds;
  final Map<String, PayoffSimulation> simulations;

  CommitmentsReady copyWith({
    List<Commitment>? commitments,
    Set<String>? busyIds,
    Map<String, PayoffSimulation>? simulations,
  }) {
    return CommitmentsReady(
      commitments ?? this.commitments,
      busyIds: busyIds ?? this.busyIds,
      simulations: simulations ?? this.simulations,
    );
  }

  @override
  List<Object?> get props => [commitments, busyIds, simulations];
}

final class CommitmentsFailed extends CommitmentsState {
  const CommitmentsFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
