import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/modules/home_module/presentation/home/widgets/day_grain.dart';

void main() {
  Widget envolver(Widget filho) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: filho),
  );

  group('DayGrain', () {
    // Acessibilidade: cor nunca é o único sinal de informação. Quem não
    // distingue verde de bege precisa do rótulo para saber o estado.
    testWidgets('o estado é anunciado, não só pintado', (tester) async {
      await tester.pumpWidget(
        envolver(const DayGrain(label: 'S', completed: true)),
      );
      expect(find.bySemanticsLabel('S, cumprido'), findsOneWidget);

      await tester.pumpWidget(
        envolver(const DayGrain(label: 'T', completed: false)),
      );
      expect(find.bySemanticsLabel('T, sem registro'), findsOneWidget);
    });

    testWidgets('cumprido e não cumprido têm cores diferentes', (tester) async {
      await tester.pumpWidget(
        envolver(
          const Row(
            children: [
              DayGrain(label: 'S', completed: true),
              DayGrain(label: 'T', completed: false),
            ],
          ),
        ),
      );

      final graos = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toList();

      expect(graos.first, isNot(graos.last));
    });
  });
}
