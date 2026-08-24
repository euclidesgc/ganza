import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_from_exception.dart';
import '../../domain/entities/chat_proposal.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Either<Failure, List<ChatProposal>>> ingest(String content) async {
    try {
      final response = await _client.functions.invoke(
        'ingest',
        body: {'content': content},
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const Left(
          UnexpectedFailure('Resposta inesperada do servidor.'),
        );
      }

      final rawProposals = data['proposals'];
      if (rawProposals is! List) {
        return const Left(
          UnexpectedFailure('Resposta inesperada do servidor.'),
        );
      }

      final proposals = <ChatProposal>[];
      for (final raw in rawProposals) {
        if (raw is! Map<String, dynamic>) continue;
        final kind = raw['kind'];
        final payload = raw['payload'];
        if (kind is! String || payload is! Map<String, dynamic>) continue;
        proposals.add(
          ChatProposal(kind: kind, payload: Map<String, dynamic>.from(payload)),
        );
      }
      return Right(proposals);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }
}
