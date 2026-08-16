import 'package:dio/dio.dart';
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
    StorageException _ => const UnexpectedFailure(
      'Não foi possível acessar o arquivo.',
    ),
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

Failure _fromPostgrest(PostgrestException error) {
  final code = error.code;
  if (code == 'PGRST301' || code == '42501') return const PermissionFailure();
  if (code == 'PGRST116') return const NotFoundFailure();
  if (code != null && (code.startsWith('22') || code.startsWith('23'))) {
    return const ValidationFailure();
  }
  return const UnexpectedFailure();
}
