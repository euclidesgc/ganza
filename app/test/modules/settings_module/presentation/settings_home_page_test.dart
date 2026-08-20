import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/modules/settings_module/settings_module.dart';
import 'package:go_router/go_router.dart';

void main() {
  GoRouter criarRoteador() => GoRouter(
    initialLocation: SettingsRoutes.path,
    routes: [SettingsRoutes.route],
  );

  Widget envolver(GoRouter roteador) =>
      MaterialApp.router(theme: AppTheme.light, routerConfig: roteador);

  group('SettingsHomePage', () {
    testWidgets('lista as três seções com rótulo textual visível', (
      tester,
    ) async {
      await tester.pumpWidget(envolver(criarRoteador()));
      await tester.pumpAndSettle();

      expect(find.text('Conta'), findsOneWidget);
      expect(find.text('IA'), findsOneWidget);
      expect(find.text('Banco'), findsOneWidget);
    });

    testWidgets('tocar em Conta navega para o destino sem lançar', (
      tester,
    ) async {
      await tester.pumpWidget(envolver(criarRoteador()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Conta'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(AppBar, 'Conta'), findsOneWidget);
    });

    testWidgets('tocar em IA navega para o destino sem lançar', (tester) async {
      await tester.pumpWidget(envolver(criarRoteador()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('IA'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(AppBar, 'IA'), findsOneWidget);
    });

    testWidgets('tocar em Banco navega para o destino sem lançar', (
      tester,
    ) async {
      await tester.pumpWidget(envolver(criarRoteador()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Banco'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(AppBar, 'Banco'), findsOneWidget);
    });
  });
}
