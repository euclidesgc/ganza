import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/chat_module/data/models/chat_proposal_model.dart';

void main() {
  group('ChatProposalModel.fromMap', () {
    test('aceita a linha completa de proposed_actions', () {
      final result = ChatProposalModel.fromMap({
        'id': 'p1',
        'kind': 'create_transaction',
        'payload': {
          'direction': 'out',
          'amount': 4500,
          'description': 'almoço',
        },
        'sequence': 1,
        'status': 'pending',
      });

      final proposal = result.getOrElse(
        (_) => fail('esperava Right, veio Left'),
      );
      expect(proposal.id, 'p1');
      expect(proposal.kind, 'create_transaction');
      expect(proposal.sequence, 1);
      expect(proposal.status, 'pending');
      expect(proposal.description, 'almoço');
    });

    test('rejeita linha sem id', () {
      final result = ChatProposalModel.fromMap({
        'kind': 'create_transaction',
        'payload': {'description': 'almoço'},
        'sequence': 1,
        'status': 'pending',
      });

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    });

    test('rejeita linha sem kind', () {
      final result = ChatProposalModel.fromMap({
        'id': 'p1',
        'payload': {'description': 'almoço'},
        'sequence': 1,
        'status': 'pending',
      });

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    });

    test('rejeita payload que não é um mapa', () {
      final result = ChatProposalModel.fromMap({
        'id': 'p1',
        'kind': 'create_transaction',
        'payload': 'não é mapa',
        'sequence': 1,
        'status': 'pending',
      });

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    });
  });
}
