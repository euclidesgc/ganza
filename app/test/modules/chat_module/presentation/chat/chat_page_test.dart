import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/modules/chat_module/domain/entities/chat_proposal.dart';
import 'package:ganza/modules/chat_module/domain/usecases/ingest_message.dart';
import 'package:ganza/modules/chat_module/presentation/chat/chat_cubit.dart';
import 'package:ganza/modules/chat_module/presentation/chat/chat_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockIngestMessage extends Mock implements IngestMessage {}

void main() {
  late MockIngestMessage ingestMessage;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    ingestMessage = MockIngestMessage();
  });

  Widget montar(ChatCubit cubit) => MaterialApp(
    theme: AppTheme.light,
    home: BlocProvider.value(
      value: cubit,
      child: const Scaffold(body: ChatPage()),
    ),
  );

  testWidgets('enviar mostra os cards de proposta retornados', (tester) async {
    final proposal = ChatProposal(
      kind: 'create_transaction',
      payload: {'direction': 'out', 'amount': 4500, 'description': 'almoço'},
    );
    when(
      () => ingestMessage('almoço no bar'),
    ).thenAnswer((_) async => Right([proposal]));

    final cubit = ChatCubit(ingestMessage);
    await tester.pumpWidget(montar(cubit));

    await tester.enterText(find.byType(TextField), 'almoço no bar');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('almoço'), findsOneWidget);
    expect(find.text('−R\$ 45,00'), findsOneWidget);
  });

  testWidgets('botão de enviar desabilitado durante o envio', (tester) async {
    final completer = Completer<Either<Failure, List<ChatProposal>>>();
    when(() => ingestMessage(any())).thenAnswer((_) => completer.future);

    final cubit = ChatCubit(ingestMessage);
    await tester.pumpWidget(montar(cubit));

    await tester.enterText(find.byType(TextField), 'oi');
    await tester.tap(find.text('Enviar'));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Enviar'),
    );
    expect(button.onPressed, isNull);

    completer.complete(const Right([]));
    await tester.pumpAndSettle();
  });
}
