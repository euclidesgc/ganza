part of 'chat_cubit.dart';

sealed class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

final class ChatIdle extends ChatState {
  const ChatIdle();
}

final class ChatSending extends ChatState {
  const ChatSending();
}

final class ChatSucceeded extends ChatState {
  const ChatSucceeded(this.proposals);

  final List<ChatProposal> proposals;

  @override
  List<Object?> get props => [proposals];
}

final class ChatFailed extends ChatState {
  const ChatFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
