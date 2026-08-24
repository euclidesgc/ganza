import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/chat_proposal.dart';
import '../repositories/chat_repository.dart';

class ListPendingProposals {
  const ListPendingProposals(this._repository);

  final ChatRepository _repository;

  Future<Either<Failure, List<ChatProposal>>> call() =>
      _repository.listPending();
}
