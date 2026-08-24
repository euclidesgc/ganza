import 'package:fpdart/fpdart.dart';
import 'package:zard/zard.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/chat_proposal.dart';

abstract final class ChatProposalModel {
  static final _schema = z.map({
    'id': z.string(),
    'kind': z.string(),
    'sequence': z.int(),
    'status': z.string(),
  });

  static Either<Failure, ChatProposal> fromMap(Map<String, dynamic> map) {
    final result = _schema.safeParse(map);
    if (!result.success || result.data == null) {
      return const Left(ValidationFailure('Proposta em formato inesperado.'));
    }

    final data = result.data!;
    final payload = map['payload'];
    if (payload is! Map<String, dynamic>) {
      return const Left(ValidationFailure('Proposta em formato inesperado.'));
    }

    return Right(
      ChatProposal(
        id: data['id'] as String,
        kind: data['kind'] as String,
        payload: Map<String, dynamic>.from(payload),
        sequence: data['sequence'] as int,
        status: data['status'] as String,
      ),
    );
  }
}
