import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import 'chat_cubit.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_proposal_card.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      BlocProvider(
        create: (_) => getIt<ChatCubit>()..load(),
        child: const ChatPage(),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: BlocBuilder<ChatCubit, ChatState>(
            builder: (context, state) => switch (state) {
              ChatReady(proposals: final proposals) when proposals.isEmpty =>
                const Center(child: Text('Nenhum registro proposto.')),
              ChatReady(proposals: final proposals) => ListView.builder(
                itemCount: proposals.length,
                itemBuilder: (context, index) =>
                    ChatProposalCard(proposal: proposals[index]),
              ),
              ChatFailed(failure: final failure) => Center(
                child: Text(failure.message),
              ),
              ChatLoading() => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
        const ChatComposer(),
      ],
    );
  }
}
