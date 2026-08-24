import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/modules/chat_module/domain/entities/chat_proposal.dart';
import 'package:ganza/modules/chat_module/domain/usecases/cancel_proposal.dart';
import 'package:ganza/modules/chat_module/domain/usecases/confirm_proposal.dart';
import 'package:ganza/modules/chat_module/domain/usecases/ingest_message.dart';
import 'package:ganza/modules/chat_module/domain/usecases/list_pending_proposals.dart';
import 'package:ganza/modules/chat_module/presentation/chat/chat_cubit.dart';
import 'package:ganza/modules/chat_module/presentation/chat/chat_page.dart';
import 'package:ganza/modules/chat_module/presentation/chat/widgets/chat_proposal_card.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockIngestMessage extends Mock implements IngestMessage {}

class MockListPendingProposals extends Mock implements ListPendingProposals {}

class MockConfirmProposal extends Mock implements ConfirmProposal {}

class MockCancelProposal extends Mock implements CancelProposal {}

void main() {
  late MockIngestMessage ingestMessage;
  late MockListPendingProposals listPending;
  late MockConfirmProposal confirm;
  late MockCancelProposal cancel;

  final proposal = ChatProposal(
    id: 'p1',
    kind: 'create_transaction',
    payload: {'direction': 'out', 'amount': 4500, 'description': 'almoço'},
    sequence: 1,
    status: 'pending',
  );

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    ingestMessage = MockIngestMessage();
    listPending = MockListPendingProposals();
    confirm = MockConfirmProposal();
    cancel = MockCancelProposal();
  });

  Widget montar(ChatCubit cubit) => MaterialApp(
    theme: AppTheme.light,
    home: BlocProvider.value(
      value: cubit,
      child: const Scaffold(body: ChatPage()),
    ),
  );

  ChatCubit cubitComPendentes() {
    when(() => listPending.call()).thenAnswer((_) async => Right([proposal]));
    return ChatCubit(ingestMessage, listPending, confirm, cancel);
  }

  testWidgets('abrir lista os pendentes com Confirmar e Cancelar', (
    tester,
  ) async {
    final cubit = cubitComPendentes();
    await cubit.load();
    await tester.pumpWidget(montar(cubit));
    await tester.pumpAndSettle();

    expect(find.text('almoço'), findsOneWidget);
    expect(find.text('−R\$ 45,00'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('o card não tem campo de texto editável', (tester) async {
    final cubit = cubitComPendentes();
    await cubit.load();
    await tester.pumpWidget(montar(cubit));
    await tester.pumpAndSettle();

    final card = find.byType(ChatProposalCard);
    expect(
      find.descendant(of: card, matching: find.byType(TextField)),
      findsNothing,
    );
  });

  testWidgets('confirmar remove o card ao refazer a leitura', (tester) async {
    var calls = 0;
    when(() => listPending.call()).thenAnswer((_) async {
      calls += 1;
      return calls == 1 ? Right([proposal]) : const Right([]);
    });
    when(() => confirm.call('p1')).thenAnswer((_) async => const Right(unit));
    final cubit = ChatCubit(ingestMessage, listPending, confirm, cancel);
    await cubit.load();
    await tester.pumpWidget(montar(cubit));
    await tester.pumpAndSettle();

    expect(find.text('almoço'), findsOneWidget);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('almoço'), findsNothing);
    expect(find.text('Nenhum registro proposto.'), findsOneWidget);
  });

  testWidgets('cancelar remove o card ao refazer a leitura', (tester) async {
    var calls = 0;
    when(() => listPending.call()).thenAnswer((_) async {
      calls += 1;
      return calls == 1 ? Right([proposal]) : const Right([]);
    });
    when(() => cancel.call('p1')).thenAnswer((_) async => const Right(unit));
    final cubit = ChatCubit(ingestMessage, listPending, confirm, cancel);
    await cubit.load();
    await tester.pumpWidget(montar(cubit));
    await tester.pumpAndSettle();

    expect(find.text('almoço'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('almoço'), findsNothing);
    expect(find.text('Nenhum registro proposto.'), findsOneWidget);
  });

  testWidgets('enviar desabilita o botão durante o envio', (tester) async {
    final completer = Completer<Either<Failure, Unit>>();
    when(() => ingestMessage.call(any())).thenAnswer((_) => completer.future);
    when(() => listPending.call()).thenAnswer((_) async => const Right([]));
    final cubit = ChatCubit(ingestMessage, listPending, confirm, cancel);
    await cubit.load();
    await tester.pumpWidget(montar(cubit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'oi');
    await tester.tap(find.text('Enviar'));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Enviar'),
    );
    expect(button.onPressed, isNull);

    completer.complete(const Right(unit));
    await tester.pumpAndSettle();
  });
}
