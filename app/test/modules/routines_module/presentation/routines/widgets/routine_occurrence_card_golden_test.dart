import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('golden do card atrasado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ontem = DateTime.now().subtract(const Duration(days: 1));
    await tester.pumpWidget(montar(ocorrencia(ontem), completionRate: 0.67));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RoutineOccurrenceCard),
      matchesGoldenFile('goldens/routine_occurrence_card_atrasada.png'),
    );
  });

  testWidgets('golden do card normal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final amanha = DateTime.now().add(const Duration(days: 1));
    await tester.pumpWidget(montar(ocorrencia(amanha)));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RoutineOccurrenceCard),
      matchesGoldenFile('goldens/routine_occurrence_card_normal.png'),
    );
  });
}
