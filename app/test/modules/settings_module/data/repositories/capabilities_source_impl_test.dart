import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/core/session/user_capabilities.dart';
import 'package:ganza/modules/settings_module/data/repositories/capabilities_source_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient _clientRespondingWith(
  http.Response Function(http.Request request) respond,
) {
  return SupabaseClient(
    'https://capabilities-test.supabase.invalid',
    'anon-key-de-teste',
    httpClient: MockClient((request) async => respond(request)),
  );
}

void main() {
  group('CapabilitiesSourceImpl.load', () {
    test(
      'credencial ativa devolve aiConfigured true e bankConnected false',
      () async {
        final client = _clientRespondingWith(
          (request) => http.Response(
            jsonEncode([
              {'id': 'cred-ativa'},
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
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
        (request) => http.Response(
          jsonEncode(<Map<String, dynamic>>[]),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
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

    test('falha da consulta devolve Left de Failure', () async {
      final client = _clientRespondingWith(
        (request) => http.Response(
          jsonEncode({'message': 'erro interno', 'code': '500'}),
          500,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      );
      final source = CapabilitiesSourceImpl(client);

      final resultado = await source.load();

      expect(resultado.isLeft(), isTrue);
      expect(resultado.getLeft().toNullable(), isA<Failure>());
    });
  });
}
