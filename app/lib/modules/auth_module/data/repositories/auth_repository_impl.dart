import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_from_exception.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/authenticated_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  AuthenticatedUser? get currentUser =>
      AuthenticatedUserModel.fromSupabase(_client.auth.currentUser);

  @override
  Stream<AuthenticatedUser?> observeCurrentUser() => _client
      .auth
      .onAuthStateChange
      .map((event) => AuthenticatedUserModel.fromSupabase(event.session?.user));

  @override
  Future<Either<Failure, AuthenticatedUser>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = AuthenticatedUserModel.fromSupabase(response.user);
      if (user == null) {
        return const Left(
          AuthFailure('Não foi possível entrar. Tente de novo.'),
        );
      }
      return Right(user);
    } on AuthException catch (error) {
      return Left(_traduzir(error));
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Right(unit);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  /// O GoTrue devolve a mesma mensagem genérica para senha errada e usuário
  /// inexistente — por desenho, para não revelar quais e-mails existem.
  Failure _traduzir(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return const AuthFailure('E-mail ou senha incorretos.');
    }
    if (message.contains('email not confirmed')) {
      return const AuthFailure('Confirme seu e-mail antes de entrar.');
    }
    return const AuthFailure();
  }
}
