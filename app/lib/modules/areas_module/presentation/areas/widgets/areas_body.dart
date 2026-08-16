import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../../../../../core/widgets/widgets.dart';
import '../areas_cubit.dart';
import 'area_tile.dart';
import 'areas_error.dart';

class AreasBody extends StatelessWidget {
  const AreasBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AreasCubit, AreasState>(
      builder: (context, state) => switch (state) {
        AreasLoading() => const Center(child: CircularProgressIndicator()),
        AreasLoadFailed(:final failure) => AreasError(message: failure.message),
        AreasEmpty() => const AreasError(
          message:
              'Nenhuma área encontrada. Isso não deveria acontecer — as quatro '
              'padrão nascem com a conta.',
        ),
        AreasLoaded(:final areas) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Hoje', style: context.texts.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ainda não há nada registrado.',
              style: context.texts.bodyMedium?.copyWith(
                color: context.ganza.mutedInk,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const WeekPulse(),
            const SizedBox(height: AppSpacing.xl),
            Text('Áreas', style: context.texts.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final area in areas)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AreaTile(area: area),
              ),
          ],
        ),
      },
    );
  }
}
