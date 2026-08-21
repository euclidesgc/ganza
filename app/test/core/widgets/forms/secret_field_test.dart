import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/theme/theme.dart';
import 'package:ganza/core/widgets/forms/secret_field.dart';

void main() {
  Widget envolver(Widget filho) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: filho),
  );

  group('SecretField', () {
    testWidgets('nasce oculto, com o botão de revelar', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        envolver(SecretField(label: 'Chave de API', controller: controller)),
      );

      expect(find.bySemanticsLabel('Mostrar a chave'), findsOneWidget);
      expect(find.bySemanticsLabel('Ocultar a chave'), findsNothing);
      expect(find.byIcon(AppIcons.revealSecret), findsOneWidget);
      expect(find.byIcon(AppIcons.hideSecret), findsNothing);
    });

    testWidgets('tocar no botão inverte o estado e o ícone', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        envolver(SecretField(label: 'Chave de API', controller: controller)),
      );

      await tester.tap(find.byIcon(AppIcons.revealSecret));
      await tester.pump();

      expect(find.bySemanticsLabel('Ocultar a chave'), findsOneWidget);
      expect(find.bySemanticsLabel('Mostrar a chave'), findsNothing);
      expect(find.byIcon(AppIcons.hideSecret), findsOneWidget);
      expect(find.byIcon(AppIcons.revealSecret), findsNothing);
    });
  });
}
