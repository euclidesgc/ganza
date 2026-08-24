import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/chat_proposal.dart';

abstract interface class ChatRepository {
  Future<Either<Failure, List<ChatProposal>>> ingest(String content);
}
