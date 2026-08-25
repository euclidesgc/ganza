part of 'chat_cubit.dart';

sealed class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

enum ChatAudioStatus { idle, recording, transcribing }

final class ChatLoading extends ChatState {
  const ChatLoading();
}

final class ChatReady extends ChatState {
  const ChatReady({
    required this.proposals,
    this.sending = false,
    this.audioStatus = ChatAudioStatus.idle,
    this.audioFailure,
    this.busyIds = const {},
  });

  final List<ChatProposal> proposals;
  final bool sending;
  final ChatAudioStatus audioStatus;
  final Failure? audioFailure;
  final Set<String> busyIds;

  bool get isBusy => sending || audioStatus != ChatAudioStatus.idle;

  ChatReady copyWith({
    List<ChatProposal>? proposals,
    bool? sending,
    ChatAudioStatus? audioStatus,
    Failure? audioFailure,
    bool clearAudioFailure = false,
    Set<String>? busyIds,
  }) {
    return ChatReady(
      proposals: proposals ?? this.proposals,
      sending: sending ?? this.sending,
      audioStatus: audioStatus ?? this.audioStatus,
      audioFailure: clearAudioFailure
          ? null
          : audioFailure ?? this.audioFailure,
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [
    proposals,
    sending,
    audioStatus,
    audioFailure,
    busyIds,
  ];
}

final class ChatFailed extends ChatState {
  const ChatFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
