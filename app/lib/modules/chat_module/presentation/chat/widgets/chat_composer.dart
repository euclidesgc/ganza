import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../chat_cubit.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({super.key});

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    context.read<ChatCubit>().send(content);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.select<ChatCubit, bool>(
      (cubit) => switch (cubit.state) {
        ChatLoading() => true,
        ChatReady(sending: final sending) => sending,
        ChatFailed() => false,
      },
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Flexible(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'Escreva uma mensagem',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: busy ? null : _send,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}
