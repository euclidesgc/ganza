import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/commitment.dart';
import '../../domain/entities/payoff_simulation.dart';
import '../../domain/usecases/list_commitments.dart';
import '../../domain/usecases/simulate_early_payoff.dart';

part 'commitments_state.dart';

class CommitmentsCubit extends Cubit<CommitmentsState> {
  CommitmentsCubit(this._listCommitments, this._simulateEarlyPayoff)
    : super(const CommitmentsLoading());

  final ListCommitments _listCommitments;
  final SimulateEarlyPayoff _simulateEarlyPayoff;

  Future<void> load() async {
    emit(const CommitmentsLoading());

    final result = await _listCommitments();
    if (isClosed) return;

    emit(result.fold(CommitmentsFailed.new, CommitmentsReady.new));
  }

  Future<void> simulate(String commitmentId) async {
    final current = state;
    if (current is! CommitmentsReady ||
        current.busyIds.contains(commitmentId)) {
      return;
    }

    Commitment? commitment;
    for (final item in current.commitments) {
      if (item.id == commitmentId) {
        commitment = item;
        break;
      }
    }
    if (commitment == null) return;

    emit(current.copyWith(busyIds: {...current.busyIds, commitmentId}));

    final result = await _simulateEarlyPayoff(commitment);
    if (isClosed) return;

    final ready = state;
    if (ready is! CommitmentsReady) return;
    final busy = {...ready.busyIds}..remove(commitmentId);

    emit(
      result.fold(
        (_) => ready.copyWith(busyIds: busy),
        (simulation) => ready.copyWith(
          busyIds: busy,
          simulations: {...ready.simulations, commitmentId: simulation},
        ),
      ),
    );
  }
}
