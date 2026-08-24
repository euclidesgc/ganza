import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/chat_proposal.dart';
import '../repositories/chat_repository.dart';

class IngestMessage {
  const IngestMessage(this._repository);

  final ChatRepository _repository;

  Future<Either<Failure, List<ChatProposal>>> call(String content) =>
      _repository.ingest(content);
}
