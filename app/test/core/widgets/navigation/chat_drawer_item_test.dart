import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/session/session.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/core/widgets/widgets.dart';
import 'package:mocktail/mocktail.dart';

class _MockCapabilitiesSource extends Mock implements CapabilitiesSource {}

void main() {
  late _MockCapabilitiesSource source;

  setUp(() {
    source = _MockCapabilitiesSource();
  });

  Widget montar(CapabilitiesCubit cubit) => MaterialApp(
    theme: AppTheme.light,
    home: BlocProvider<CapabilitiesCubit>.value(
      value: cubit,
      child: Scaffold(
        drawer: Drawer(child: ChatDrawerItem(onSelected: () {})),
      ),
    ),
  );

  testWidgets(
    'com a IA não configurada, o item aparece desabilitado com o motivo '
    'visível e no rótulo de Semantics',
    (tester) async {
      when(
        () => source.load(),
      ).thenAnswer((_) async => const Right(UserCapabilities.unresolved()));
      final cubit = CapabilitiesCubit(source)..refresh();
      await tester.pumpWidget(montar(cubit));
      await tester.pumpAndSettle();

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Configure a IA para usar o chat.'), findsOneWidget);

      final semantics = tester.getSemantics(find.text('Chat').first);
      expect(semantics.label, 'Chat. Configure a IA para usar o chat.');

      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTile.enabled, isFalse);
    },
  );

  testWidgets('com a IA configurada, o item acende e não mostra motivo', (
    tester,
  ) async {
    when(() => source.load()).thenAnswer(
      (_) async => const Right(
        UserCapabilities(aiConfigured: true, bankConnected: false),
      ),
    );
    final cubit = CapabilitiesCubit(source)..refresh();
    await tester.pumpWidget(montar(cubit));
    await tester.pumpAndSettle();

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Configure a IA para usar o chat.'), findsNothing);

    final listTile = tester.widget<ListTile>(find.byType(ListTile));
    expect(listTile.enabled, isTrue);
  });
}
