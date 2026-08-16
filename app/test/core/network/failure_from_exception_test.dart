import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/core/network/failure_from_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  DioException respostaCom(int status) => DioException(
    requestOptions: RequestOptions(),
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: RequestOptions(), statusCode: status),
  );

  group('failureFromException', () {
    test('timeout e falha de conexão viram NetworkFailure', () {
      for (final tipo in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.connectionError,
      ]) {
        final falha = failureFromException(
          DioException(requestOptions: RequestOptions(), type: tipo),
        );
        expect(falha, isA<NetworkFailure>(), reason: tipo.name);
      }
    });

    test('status HTTP vira a Failure correspondente', () {
      expect(failureFromException(respostaCom(400)), isA<ValidationFailure>());
      expect(failureFromException(respostaCom(401)), isA<AuthFailure>());
      expect(failureFromException(respostaCom(403)), isA<PermissionFailure>());
      expect(failureFromException(respostaCom(404)), isA<NotFoundFailure>());
      expect(failureFromException(respostaCom(500)), isA<UnexpectedFailure>());
    });

    test('RLS negando acesso vira PermissionFailure, não erro genérico', () {
      final falha = failureFromException(
        const PostgrestException(message: 'permission denied', code: '42501'),
      );
      expect(falha, isA<PermissionFailure>());
    });

    test('violação de constraint vira ValidationFailure', () {
      final falha = failureFromException(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );
      expect(falha, isA<ValidationFailure>());
    });

    test('exceção desconhecida não vaza como outra coisa', () {
      expect(failureFromException(Exception('vixe')), isA<UnexpectedFailure>());
    });
  });
}
