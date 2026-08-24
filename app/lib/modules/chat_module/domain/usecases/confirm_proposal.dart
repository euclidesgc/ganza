import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/chat_repository.dart';

class ConfirmProposal {
  const ConfirmProposal(this._repository);

  final ChatRepository _repository;

  Future<Either<Failure, Unit>> call(String proposalId) =>
      _repository.confirm(proposalId);
}
