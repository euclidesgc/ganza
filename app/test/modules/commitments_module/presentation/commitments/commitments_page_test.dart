import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/modules/commitments_module/domain/entities/commitment.dart';
import 'package:ganza/modules/commitments_module/domain/entities/commitment_direction.dart';
import 'package:ganza/modules/commitments_module/domain/entities/payoff_simulation.dart';
import 'package:ganza/modules/commitments_module/domain/usecases/list_commitments.dart';
import 'package:ganza/modules/commitments_module/domain/usecases/simulate_early_payoff.dart';
import 'package:ganza/modules/commitments_module/presentation/commitments/commitments_cubit.dart';
import 'package:ganza/modules/commitments_module/presentation/commitments/commitments_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockListCommitments extends Mock implements ListCommitments {}

class MockSimulateEarlyPayoff extends Mock implements SimulateEarlyPayoff {}

void main() {
  late MockListCommitments listCommitments;
  late MockSimulateEarlyPayoff simulateEarlyPayoff;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    listCommitments = MockListCommitments();
    simulateEarlyPayoff = MockSimulateEarlyPayoff();
  });

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

  testWidgets('lista o compromisso com o botão de simular', (tester) async {
    when(
      () => listCommitments.call(),
    ).thenAnswer((_) async => Right([commitment]));

    final cubit = CommitmentsCubit(listCommitments, simulateEarlyPayoff);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: CommitmentsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Financiamento do carro'), findsOneWidget);
    expect(find.text('Simular quitação'), findsOneWidget);
  });

  testWidgets('simular chama o use case e mostra o valor presente', (
    tester,
  ) async {
    when(
      () => listCommitments.call(),
    ).thenAnswer((_) async => Right([commitment]));
    when(
      () => simulateEarlyPayoff.call(commitment),
    ).thenAnswer((_) async => Right(simulation));

    final cubit = CommitmentsCubit(listCommitments, simulateEarlyPayoff);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: CommitmentsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simular quitação'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Quitar por'), findsOneWidget);
    verify(() => simulateEarlyPayoff.call(commitment)).called(1);
  });
}
