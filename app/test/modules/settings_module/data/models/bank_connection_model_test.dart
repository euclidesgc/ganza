import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/settings_module/data/models/bank_connection_model.dart';
import 'package:ganza/modules/settings_module/domain/entities/bank_connection_status.dart';

void main() {
  Map<String, dynamic> linhaValida() => {
    'id': 'conn-1',
    'institution_name': 'Banco Ganzá',
    'status': 'connected',
    'last_synced_at': '2026-08-20T12:00:00Z',
  };

  group('BankConnectionModel.fromMap', () {
    test('linha do PostgREST vira entidade', () {
      final resultado = BankConnectionModel.fromMap(linhaValida());
      final connection = resultado.getOrElse(
        (_) => throw StateError('esperava sucesso'),
      );

      expect(connection.id, 'conn-1');
      expect(connection.institution, 'Banco Ganzá');
      expect(connection.status, BankConnectionStatus.connected);
      expect(connection.lastSyncedAt, DateTime.utc(2026, 8, 20, 12));
      expect(connection.lastSyncedAt!.isUtc, isTrue);
    });

    test('conexão nunca sincronizada vem com last_synced_at nulo', () {
      final semSincronizacao = linhaValida()..['last_synced_at'] = null;
      final resultado = BankConnectionModel.fromMap(semSincronizacao);
      final connection = resultado.getOrElse(
        (_) => throw StateError('esperava sucesso'),
      );

      expect(connection.lastSyncedAt, isNull);
    });

    // Se a migration mudar a check constraint de `status`, isto precisa
    // falhar aqui — e não virar um estado inventado três telas adiante.
    test('status fora dos quatro valores do enum vira ValidationFailure', () {
      final statusDesconhecido = linhaValida()..['status'] = 'em_analise';

      expect(
        BankConnectionModel.fromMap(statusDesconhecido).getLeft().toNullable(),
        isA<ValidationFailure>(),
      );
    });

    test('coluna faltando vira ValidationFailure, não nulo silencioso', () {
      final semInstituicao = linhaValida()..remove('institution_name');

      expect(
        BankConnectionModel.fromMap(semInstituicao).getLeft().toNullable(),
        isA<ValidationFailure>(),
      );
    });
  });

  group('BankConnectionModel.accessTokenFromMap', () {
    test('resposta de connect_token vira o token de acesso', () {
      final resultado = BankConnectionModel.accessTokenFromMap({
        'access_token': 'valor-de-teste-placeholder',
      });

      expect(
        resultado.getOrElse((_) => throw StateError('esperava sucesso')),
        'valor-de-teste-placeholder',
      );
    });

    test('resposta sem access_token vira ValidationFailure', () {
      expect(
        BankConnectionModel.accessTokenFromMap(
          <String, dynamic>{},
        ).getLeft().toNullable(),
        isA<ValidationFailure>(),
      );
    });
  });
}
