import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_from_exception.dart';
import '../../domain/entities/chat_proposal.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/chat_proposal_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl(this._client);

  final SupabaseClient _client;

  /// O `/ingest` só acusa recebimento: a fonte de verdade dos cards é a
  /// leitura de `proposed_actions` em [listPending]. Reusar a resposta aqui
  /// duplicaria o critério de dono e de `status` em dois lugares.
  @override
  Future<Either<Failure, Unit>> ingest(String content) async {
    try {
      await _client.functions.invoke('ingest', body: {'content': content});
      return const Right(unit);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  /// Sem filtro por usuário na query: quem decide o que este usuário enxerga
  /// é a RLS. Replicar a regra aqui daria a impressão de proteção e criaria
  /// dois lugares para errar.
  @override
  Future<Either<Failure, List<ChatProposal>>> listPending() async {
    try {
      final rows = await _client
          .from('proposed_actions')
          .select('id, kind, payload, sequence, status')
          .eq('status', 'pending')
          .order('sequence');

      final proposals = <ChatProposal>[];
      for (final row in rows) {
        final parsed = ChatProposalModel.fromMap(row);
        if (parsed.isLeft()) {
          return parsed.map((proposal) => <ChatProposal>[proposal]);
        }
        proposals.add(
          parsed.getOrElse((_) => throw StateError('inalcançável')),
        );
      }
      return Right(proposals);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> confirm(String proposalId) async {
    try {
      await _client.functions.invoke(
        'proposals',
        body: {'proposal_id': proposalId, 'action': 'confirm'},
      );
      return const Right(unit);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> cancel(String proposalId) async {
    try {
      await _client.functions.invoke(
        'proposals',
        body: {'proposal_id': proposalId, 'action': 'cancel'},
      );
      return const Right(unit);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }
}
