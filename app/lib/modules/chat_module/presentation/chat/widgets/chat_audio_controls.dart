import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../chat_cubit.dart';

class ChatAudioControls extends StatelessWidget {
  const ChatAudioControls({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select<ChatCubit, ChatReady?>(
      (cubit) => switch (cubit.state) {
        ChatReady() => cubit.state as ChatReady,
        _ => null,
      },
    );
    final failure = state?.audioFailure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (failure != null) ...[
          Semantics(
            liveRegion: true,
            label: failure.message,
            child: Text(
              failure.message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        switch (state?.audioStatus ?? ChatAudioStatus.idle) {
          ChatAudioStatus.idle => Semantics(
            button: true,
            label: 'Gravar áudio',
            child: IconButton(
              key: const Key('chat_start_audio_recording'),
              tooltip: 'Gravar áudio',
              onPressed: state == null || state.isBusy
                  ? null
                  : context.read<ChatCubit>().startAudioRecording,
              icon: const Icon(AppIcons.microphone),
            ),
          ),
          ChatAudioStatus.recording => Row(
            children: [
              Semantics(
                liveRegion: true,
                label: 'Gravando áudio',
                child: const Text('Gravando áudio…'),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                key: const Key('chat_stop_audio_recording'),
                tooltip: 'Parar gravação e transcrever',
                onPressed: context.read<ChatCubit>().stopAudioRecording,
                icon: const Icon(AppIcons.stopRecording),
              ),
              TextButton(
                key: const Key('chat_cancel_audio_recording'),
                onPressed: context.read<ChatCubit>().cancelAudioRecording,
                child: const Text('Cancelar áudio'),
              ),
            ],
          ),
          ChatAudioStatus.transcribing => Semantics(
            liveRegion: true,
            label: 'Transcrevendo áudio',
            child: Row(
              children: [
                SizedBox(
                  width: AppSpacing.md,
                  height: AppSpacing.md,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.sm),
                Text('Transcrevendo áudio…'),
              ],
            ),
          ),
        },
      ],
    );
  }
}
