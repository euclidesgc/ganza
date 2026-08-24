import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/chat_proposal.dart';
import '../../domain/usecases/ingest_message.dart';

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._ingestMessage) : super(const ChatIdle());

  final IngestMessage _ingestMessage;

  Future<void> send(String content) async {
    emit(const ChatSending());

    final result = await _ingestMessage(content);
    if (isClosed) return;

    emit(
      result.fold(
        ChatFailed.new,
        (proposals) => proposals.isEmpty
            ? const ChatSucceeded([])
            : ChatSucceeded(proposals),
      ),
    );
  }
}
