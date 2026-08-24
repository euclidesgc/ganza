import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../injection.dart';
import 'routines_cubit.dart';
import 'widgets/routine_occurrence_card.dart';

class RoutinesPage extends StatelessWidget {
  const RoutinesPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      BlocProvider(
        create: (_) => getIt<RoutinesCubit>()..load(),
        child: const RoutinesPage(),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: BlocBuilder<RoutinesCubit, RoutinesState>(
            builder: (context, state) => switch (state) {
              RoutinesReady(occurrences: final occurrences)
                  when occurrences.isEmpty =>
                const Center(child: Text('Nenhuma rotina pendente.')),
              RoutinesReady(occurrences: final occurrences) => ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  for (final occurrence in occurrences)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: RoutineOccurrenceCard(occurrence: occurrence),
                    ),
                ],
              ),
              RoutinesFailed(failure: final failure) => Center(
                child: Text(failure.message),
              ),
              RoutinesLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            },
          ),
        ),
      ],
    );
  }
}
