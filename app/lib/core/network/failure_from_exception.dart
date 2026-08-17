import 'dart:async';

import 'package:dio/dio.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../error/failure.dart';

/// Tradutor único de exceção para `Failure`. Vive no core porque as duas
/// fontes (Supabase e backend) atravessam vários módulos, mas quem o chama
/// é sempre a camada data — nenhuma outra tem try/catch.
Failure failureFromException(Object error) {
  return switch (error) {
    DioException e => _fromDio(e),
    AuthException _ => const AuthFailure(),
    PostgrestException e => _fromPostgrest(e),
    FunctionException e => _fromFunction(e),
    StorageException _ => const UnexpectedFailure(
      'Não foi possível acessar o arquivo.',
    ),
    // PostgREST e GoTrue não embrulham falha de transporte — o `send()` do
    // http propaga a exceção do socket como está. No nativo isso chega como
    // `ClientException` (que também implementa `SocketException`); no web,
    // o navegador embrulha qualquer falha de fetch/CORS do mesmo jeito. Um
    // `ClientException` cobre as duas plataformas sem precisar de `dart:io`,
    // que não existe no build web.
    ClientException _ => const NetworkFailure(),
    TimeoutException _ => const NetworkFailure(),
    _ => const UnexpectedFailure(),
  };
}

Failure _fromDio(DioException error) {
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.connectionError => const NetworkFailure(),
    DioExceptionType.badResponse => switch (error.response?.statusCode) {
      400 || 422 => const ValidationFailure(),
      401 => const AuthFailure(),
      403 => const PermissionFailure(),
      404 => const NotFoundFailure(),
      _ => const UnexpectedFailure(),
    },
    _ => const UnexpectedFailure(),
  };
}

Failure _fromFunction(FunctionException error) {
  // `FunctionsFetchException` é o único caso em que o pedido nem chegou ao
  // servidor (status sempre 0) — as demais subclasses carregam um status
  // HTTP de verdade, que é o que a decisão A4 pede traduzir.
  if (error is FunctionsFetchException) return const NetworkFailure();
  return switch (error.status) {
    400 => const ValidationFailure(),
    401 => const AuthFailure(),
    403 => const PermissionFailure(),
    _ => const UnexpectedFailure(),
  };
}

Failure _fromPostgrest(PostgrestException error) {
  final code = error.code;
  if (code == 'PGRST301' || code == '42501') return const PermissionFailure();
  if (code == 'PGRST116') return const NotFoundFailure();
  if (code != null && (code.startsWith('22') || code.startsWith('23'))) {
    return const ValidationFailure();
  }
  return const UnexpectedFailure();
}
