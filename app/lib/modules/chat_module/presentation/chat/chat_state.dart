part of 'chat_cubit.dart';

sealed class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

final class ChatLoading extends ChatState {
  const ChatLoading();
}

final class ChatReady extends ChatState {
  const ChatReady({
    required this.proposals,
    this.sending = false,
    this.busyIds = const {},
  });

  final List<ChatProposal> proposals;
  final bool sending;
  final Set<String> busyIds;

  ChatReady copyWith({
    List<ChatProposal>? proposals,
    bool? sending,
    Set<String>? busyIds,
  }) {
    return ChatReady(
      proposals: proposals ?? this.proposals,
      sending: sending ?? this.sending,
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [proposals, sending, busyIds];
}

final class ChatFailed extends ChatState {
  const ChatFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
