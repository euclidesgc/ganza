import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/theme/app_theme.dart';
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

void main() {
  late MockListPendingOccurrences listPending;
  late MockListRoutineSummaries listSummaries;
  late MockResolveOccurrence resolveOccurrence;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    listPending = MockListPendingOccurrences();
    listSummaries = MockListRoutineSummaries();
    resolveOccurrence = MockResolveOccurrence();
    when(() => listSummaries.call()).thenAnswer((_) async => const Right([]));
  });

  final hoje = DateTime.now();

  Widget montar(RoutineOccurrence occurrence) {
    final cubit = RoutinesCubit(listPending, listSummaries, resolveOccurrence);
    return MaterialApp(
      theme: AppTheme.light,
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(body: RoutineOccurrenceCard(occurrence: occurrence)),
      ),
    );
  }

  RoutineOccurrence ocorrencia({required DateTime dueDate}) =>
      RoutineOccurrence(
        id: 'o1',
        routineId: 'r1',
        routineName: 'Banho no cachorro',
        sequence: 1,
        dueDate: dueDate,
        status: OccurrenceStatus.pending,
      );

  testWidgets('mostra o nome e a data da ocorrência', (tester) async {
    await tester.pumpWidget(montar(ocorrencia(dueDate: hoje)));

    expect(find.text('Banho no cachorro'), findsOneWidget);
    expect(find.text('Feita'), findsOneWidget);
    expect(find.text('Adiar'), findsOneWidget);
  });

  testWidgets('atrasada mostra o rótulo de atraso', (tester) async {
    final ontem = hoje.subtract(const Duration(days: 1));
    await tester.pumpWidget(montar(ocorrencia(dueDate: ontem)));

    expect(find.text('Atrasada'), findsOneWidget);
  });

  testWidgets('futura não mostra o rótulo de atraso', (tester) async {
    final amanha = hoje.add(const Duration(days: 1));
    await tester.pumpWidget(montar(ocorrencia(dueDate: amanha)));

    expect(find.text('Atrasada'), findsNothing);
  });

  testWidgets('tocar em Feita chama resolve', (tester) async {
    when(
      () => resolveOccurrence.call('o1', 'done'),
    ).thenAnswer((_) async => const Right(unit));
    when(() => listPending.call()).thenAnswer((_) async => const Right([]));

    final cubit = RoutinesCubit(listPending, listSummaries, resolveOccurrence);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: RoutineOccurrenceCard(occurrence: ocorrencia(dueDate: hoje)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Feita'));
    await tester.pumpAndSettle();

    verify(() => resolveOccurrence.call('o1', 'done')).called(1);
  });
}
