import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/theme/theme.dart';
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

Future<void> _carregarFontes() async {
  await (FontLoader(
    AppTypography.familiaCorpo,
  )..addFont(rootBundle.load('assets/fonts/IBMPlexSans.ttf'))).load();
  await (FontLoader(
    AppTypography.familiaTitulo,
  )..addFont(rootBundle.load('assets/fonts/Fraunces.ttf'))).load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _carregarFontes();
    await initializeDateFormatting('pt_BR');
  });

  final proposal = ChatProposal(
    id: 'p1',
    kind: 'create_transaction',
    payload: {
      'direction': 'out',
      'amount': 4500,
      'description': 'almoço no bar',
    },
    sequence: 1,
    status: 'pending',
  );

  testWidgets('golden do card de proposta', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final cubit = ChatCubit(
      MockIngestMessage(),
      MockListPendingProposals(),
      MockConfirmProposal(),
      MockCancelProposal(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(body: ChatProposalCard(proposal: proposal)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ChatProposalCard),
      matchesGoldenFile('goldens/chat_proposal_card.png'),
    );
  });

  testWidgets('golden do estado vazio do chat', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final listPending = MockListPendingProposals();
    when(() => listPending.call()).thenAnswer((_) async => const Right([]));
    final cubit = ChatCubit(
      MockIngestMessage(),
      listPending,
      MockConfirmProposal(),
      MockCancelProposal(),
    );
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: ChatPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ChatPage),
      matchesGoldenFile('goldens/chat_empty.png'),
    );
  });
}
