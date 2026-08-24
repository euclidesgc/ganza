import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/modules/commitments_module/domain/entities/commitment.dart';
import 'package:ganza/modules/commitments_module/domain/entities/commitment_direction.dart';
import 'package:ganza/modules/commitments_module/domain/entities/payoff_simulation.dart';
import 'package:ganza/modules/commitments_module/domain/usecases/list_commitments.dart';
import 'package:ganza/modules/commitments_module/domain/usecases/simulate_early_payoff.dart';
import 'package:ganza/modules/commitments_module/presentation/commitments/commitments_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockListCommitments extends Mock implements ListCommitments {}

class MockSimulateEarlyPayoff extends Mock implements SimulateEarlyPayoff {}

void main() {
  late MockListCommitments listCommitments;
  late MockSimulateEarlyPayoff simulateEarlyPayoff;

  final commitment = Commitment(
    id: 'c1',
    name: 'Financiamento do carro',
    direction: CommitmentDirection.outgoing,
    valueMode: 'installment',
    totalAmount: 6000000,
    installmentsTotal: 48,
    interestRateMonthly: 0.012,
    amortizationSystem: 'price',
    outstandingBalance: 6000000,
  );

  final simulation = PayoffSimulation(
    presentValue: 5000000,
    nominalTotal: 6000000,
  );

  setUp(() {
    listCommitments = MockListCommitments();
    simulateEarlyPayoff = MockSimulateEarlyPayoff();
  });

  CommitmentsCubit buildCubit() =>
      CommitmentsCubit(listCommitments, simulateEarlyPayoff);

  blocTest<CommitmentsCubit, CommitmentsState>(
    'load emite Loading e Ready com os compromissos',
    build: buildCubit,
    act: (cubit) async {
      when(
        () => listCommitments.call(),
      ).thenAnswer((_) async => Right([commitment]));
      await cubit.load();
    },
    expect: () => [
      const CommitmentsLoading(),
      CommitmentsReady([commitment]),
    ],
  );

  blocTest<CommitmentsCubit, CommitmentsState>(
    'simulate guarda o resultado no mapa',
    build: buildCubit,
    act: (cubit) async {
      when(
        () => listCommitments.call(),
      ).thenAnswer((_) async => Right([commitment]));
      when(
        () => simulateEarlyPayoff.call(commitment),
      ).thenAnswer((_) async => Right(simulation));
      await cubit.load();
      await cubit.simulate('c1');
    },
    verify: (_) {
      verify(() => simulateEarlyPayoff.call(commitment)).called(1);
    },
    expect: () => [
      const CommitmentsLoading(),
      CommitmentsReady([commitment]),
      CommitmentsReady([commitment], busyIds: {'c1'}),
      CommitmentsReady([commitment], simulations: {'c1': simulation}),
    ],
  );
}
