import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import 'widgets/ganza_mark.dart';
import 'widgets/week_pulse.dart';

/// O som é contínuo, não é evento: a tela inicial mostra hoje e esta semana.
/// Relatório é coisa que se vai buscar, não que salta na frente.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      const HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganzá')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GanzaMark(),
            const SizedBox(height: AppSpacing.lg),
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
          ],
        ),
      ),
    );
  }
}
