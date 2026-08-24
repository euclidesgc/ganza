import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/theme/theme.dart';
import 'package:ganza/modules/commitments_module/domain/entities/commitment.dart';
import 'package:ganza/modules/commitments_module/domain/entities/commitment_direction.dart';
import 'package:ganza/modules/commitments_module/domain/entities/payoff_simulation.dart';
import 'package:ganza/modules/commitments_module/domain/usecases/list_commitments.dart';
import 'package:ganza/modules/commitments_module/domain/usecases/simulate_early_payoff.dart';
import 'package:ganza/modules/commitments_module/presentation/commitments/commitments_cubit.dart';
import 'package:ganza/modules/commitments_module/presentation/commitments/widgets/commitment_card.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockListCommitments extends Mock implements ListCommitments {}

class MockSimulateEarlyPayoff extends Mock implements SimulateEarlyPayoff {}

Future<void> _carregarFontes() async {
  await (FontLoader(
    AppTypography.familiaCorpo,
  )..addFont(rootBundle.load('assets/fonts/IBMPlexSans.ttf'))).load();
  await (FontLoader(
    AppTypography.familiaTitulo,
  )..addFont(rootBundle.load('assets/fonts/Fraunces.ttf'))).load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _carregarFontes();
    await initializeDateFormatting('pt_BR');
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

  Widget montar({PayoffSimulation? simulation}) {
    final cubit = CommitmentsCubit(
      MockListCommitments(),
      MockSimulateEarlyPayoff(),
    );
    return MaterialApp(
      theme: AppTheme.light,
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(
          body: CommitmentCard(commitment: commitment, simulation: simulation),
        ),
      ),
    );
  }

  testWidgets('golden do card sem simulação', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CommitmentCard),
      matchesGoldenFile('goldens/commitment_card_sem_simulacao.png'),
    );
  });

  testWidgets('golden do card com simulação', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      montar(
        simulation: PayoffSimulation(
          presentValue: 5000000,
          nominalTotal: 6000000,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CommitmentCard),
      matchesGoldenFile('goldens/commitment_card_com_simulacao.png'),
    );
  });
}
