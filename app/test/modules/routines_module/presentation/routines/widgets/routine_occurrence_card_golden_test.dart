import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/format/format.dart';
import 'package:ganza/core/theme/theme.dart';
import 'package:ganza/modules/routines_module/domain/entities/occurrence_status.dart';
import 'package:ganza/modules/routines_module/domain/entities/routine_occurrence.dart';
import 'package:ganza/modules/routines_module/domain/usecases/list_pending_occurrences.dart';
import 'package:ganza/modules/routines_module/domain/usecases/list_routine_summaries.dart';
import 'package:ganza/modules/routines_module/domain/usecases/resolve_occurrence.dart';
import 'package:ganza/modules/routines_module/presentation/routines/routines_cubit.dart';
import 'package:ganza/modules/routines_module/presentation/routines/widgets/routine_occurrence_card.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockListPendingOccurrences extends Mock
    implements ListPendingOccurrences {}

class MockListRoutineSummaries extends Mock implements ListRoutineSummaries {}

class MockResolveOccurrence extends Mock implements ResolveOccurrence {}

/// O card imprime a data da ocorrência, e o golden compara pixels: fixture
/// derivada do relógio (`hoje - 1 dia`) muda o texto renderizado a cada dia e
/// quebra a imagem sozinha, sem ninguém ter tocado no app. Estas duas datas
/// são fixas e ficam longe o bastante do presente para que "vencida" e
/// "futura" continuem verdadeiras em qualquer dia de execução — o que o teste
/// `as datas de referência não dependem do dia da execução` cobra.
final dataVencida = DateTime(2024, 3, 11);
final dataFutura = DateTime(2099, 3, 13);

const textoDataVencida = '11/03/2024, segunda';
const textoDataFutura = '13/03/2099, sexta';

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

  Widget montar(RoutineOccurrence occurrence, {double? completionRate}) {
    final cubit = RoutinesCubit(
      MockListPendingOccurrences(),
      MockListRoutineSummaries(),
      MockResolveOccurrence(),
    );
    return MaterialApp(
      theme: AppTheme.light,
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(
          body: RoutineOccurrenceCard(
            occurrence: occurrence,
            completionRate: completionRate,
          ),
        ),
      ),
    );
  }

  RoutineOccurrence ocorrencia(DateTime dueDate) => RoutineOccurrence(
    id: 'o1',
    routineId: 'r1',
    routineName: 'Banho no cachorro',
    sequence: 1,
    dueDate: dueDate,
    status: OccurrenceStatus.pending,
  );

  test('as datas de referência não dependem do dia da execução', () {
    final relogiosPossiveis = [
      DateTime(2026, 1, 1),
      DateTime(2026, 8, 27),
      DateTime(2050, 6, 15),
      DateTime(2098, 12, 31),
    ];

    for (final hoje in relogiosPossiveis) {
      expect(ocorrencia(dataVencida).isOverdueOn(hoje), isTrue);
      expect(ocorrencia(dataFutura).isOverdueOn(hoje), isFalse);
      expect(formatTransactionDate(dataVencida, now: hoje), textoDataVencida);
      expect(formatTransactionDate(dataFutura, now: hoje), textoDataFutura);
    }
  });

  testWidgets('golden do card atrasado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      montar(ocorrencia(dataVencida), completionRate: 0.67),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RoutineOccurrenceCard),
      matchesGoldenFile('goldens/routine_occurrence_card_atrasada.png'),
    );
  });

  testWidgets('golden do card normal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(montar(ocorrencia(dataFutura)));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RoutineOccurrenceCard),
      matchesGoldenFile('goldens/routine_occurrence_card_normal.png'),
    );
  });
}
