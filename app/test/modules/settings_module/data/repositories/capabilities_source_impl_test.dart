import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/core/session/user_capabilities.dart';
import 'package:ganza/modules/settings_module/data/repositories/capabilities_source_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

http.Response _rowsResponse(
  http.Request request,
  List<Map<String, dynamic>> rows,
) {
  return http.Response(
    jsonEncode(rows),
    200,
    request: request,
    headers: {'content-type': 'application/json'},
  );
}

http.Response _emptyRows(http.Request request) => _rowsResponse(request, []);

SupabaseClient _clientRespondingWith({
  required http.Response Function(http.Request request) aiCredentials,
  required http.Response Function(http.Request request) bankConnections,
}) {
  return SupabaseClient(
    'https://capabilities-test.supabase.invalid',
    'anon-key-de-teste',
    httpClient: MockClient((request) async {
      if (request.url.path.contains('ai_user_credentials')) {
        return aiCredentials(request);
      }
      if (request.url.path.contains('bank_connections')) {
        return bankConnections(request);
      }
      throw StateError('rota inesperada: ${request.url}');
    }),
  );
}

void main() {
  group('CapabilitiesSourceImpl.load', () {
    test(
      'credencial ativa devolve aiConfigured true e bankConnected false',
      () async {
        final client = _clientRespondingWith(
          aiCredentials: (request) => _rowsResponse(request, [
            {'id': 'cred-ativa'},
          ]),
          bankConnections: _emptyRows,
        );
        final source = CapabilitiesSourceImpl(client);

        final resultado = await source.load();

        expect(
          resultado,
          const Right<Failure, UserCapabilities>(
            UserCapabilities(aiConfigured: true, bankConnected: false),
          ),
        );
      },
    );

    test('nenhuma credencial ativa devolve aiConfigured false', () async {
      final client = _clientRespondingWith(
        aiCredentials: _emptyRows,
        bankConnections: _emptyRows,
      );
      final source = CapabilitiesSourceImpl(client);

      final resultado = await source.load();

      expect(
        resultado,
        const Right<Failure, UserCapabilities>(
          UserCapabilities(aiConfigured: false, bankConnected: false),
        ),
      );
    });

    // A capacidade de banco sai da tabela `bank_connections`, não de um
    // valor fixo no binário: com uma conexão ativa na fonte ela é
    // verdadeira, e sem nenhuma linha ela é falsa (caso acima).
    test('conexão bancária ativa devolve bankConnected true', () async {
      final client = _clientRespondingWith(
        aiCredentials: _emptyRows,
        bankConnections: (request) => _rowsResponse(request, [
          {'id': 'conn-ativa'},
        ]),
      );
      final source = CapabilitiesSourceImpl(client);

      final resultado = await source.load();

      expect(
        resultado,
        const Right<Failure, UserCapabilities>(
          UserCapabilities(aiConfigured: false, bankConnected: true),
        ),
      );
    });

    test('falha da consulta devolve Left de Failure', () async {
      final client = _clientRespondingWith(
        aiCredentials: (request) => http.Response(
          jsonEncode({'message': 'erro interno', 'code': '500'}),
          500,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
        bankConnections: _emptyRows,
      );
      final source = CapabilitiesSourceImpl(client);

      final resultado = await source.load();

      expect(resultado.isLeft(), isTrue);
      expect(resultado.getLeft().toNullable(), isA<Failure>());
    });
  });
}
