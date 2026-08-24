import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../injection.dart';
import 'commitments_cubit.dart';
import 'widgets/commitment_card.dart';

class CommitmentsPage extends StatelessWidget {
  const CommitmentsPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      BlocProvider(
        create: (_) => getIt<CommitmentsCubit>()..load(),
        child: const CommitmentsPage(),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: BlocBuilder<CommitmentsCubit, CommitmentsState>(
            builder: (context, state) => switch (state) {
              CommitmentsReady(commitments: final commitments)
                  when commitments.isEmpty =>
                const Center(child: Text('Nenhum compromisso.')),
              CommitmentsReady(
                commitments: final commitments,
                simulations: final simulations,
                busyIds: final busyIds,
              ) =>
                ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    for (final commitment in commitments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: CommitmentCard(
                          commitment: commitment,
                          simulation: simulations[commitment.id],
                          busy: busyIds.contains(commitment.id),
                        ),
                      ),
                  ],
                ),
              CommitmentsFailed(failure: final failure) => Center(
                child: Text(failure.message),
              ),
              CommitmentsLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            },
          ),
        ),
      ],
    );
  }
}
