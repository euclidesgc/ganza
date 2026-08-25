import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/theme/theme.dart';
import 'package:ganza/core/widgets/forms/password_field.dart';

void main() {
  testWidgets('revela e oculta somente a senha digitada', (tester) async {
    final controller = TextEditingController(text: 'senha-segura');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PasswordField(controller: controller, label: 'Senha'),
        ),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
    expect(find.bySemanticsLabel('Mostrar senha'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Mostrar senha'));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isFalse,
    );
    expect(find.bySemanticsLabel('Ocultar senha'), findsOneWidget);
  });
}
