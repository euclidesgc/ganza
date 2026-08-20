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

  @override
  Future<Either<Failure, Unit>> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signUp(email: email, password: password);
      return const Right(unit);
    } on AuthException catch (error) {
      // `user_already_exists` não pode virar mensagem própria: revelar que
      // o endereço está cadastrado transforma o cadastro num oráculo de
      // enumeração (FD-025, docs/002_conta_e_configuracoes/decisions.md).
      if (error.code == 'user_already_exists') return const Right(unit);
      return Left(_traduzir(error));
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> resetPasswordForEmail({
    required String email,
  }) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return const Right(unit);
    } on AuthException catch (error) {
      // `over_email_send_rate_limit` só dispara quando o GoTrue de fato
      // envia e-mail: para endereço sem conta nada é enviado, então o
      // pedido nunca esbarra nesse limite. Devolver a mensagem própria
      // (usada em signUp, onde o canal é uniforme) faria da segunda
      // tentativa um oráculo de enumeração aqui — medido contra o GoTrue
      // local, FD-028 em docs/002_conta_e_configuracoes/decisions.md.
      if (error.code == 'over_email_send_rate_limit') return const Right(unit);
      return Left(_traduzir(error));
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> verifyRecoveryCode({
    required String email,
    required String token,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      return const Right(unit);
    } on AuthException catch (error) {
      return Left(_traduzir(error));
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> updatePassword({
    required String newPassword,
  }) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return const Right(unit);
    } on AuthException catch (error) {
      return Left(_traduzir(error));
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  /// Mapeia pelo `code` do GoTrue (https://supabase.com/docs/guides/auth/debugging/error-codes),
  /// nunca pela mensagem em inglês — só o código é estável entre versões.
  Failure _traduzir(AuthException error) {
    if (error is AuthRetryableFetchException) {
      return const NetworkFailure();
    }
    // Comparação por String, não por `ErrorCode.fromCode`: o enum do
    // pacote gotrue-2.27.2 não lista 'invalid_credentials' — usar o enum
    // faria o caso mais comum de login cair no fallback genérico.
    return switch (error.code) {
      'invalid_credentials' => const AuthFailure('E-mail ou senha incorretos.'),
      'email_not_confirmed' => const AuthFailure(
        'Confirme seu e-mail antes de entrar.',
      ),
      'weak_password' => const ValidationFailure(
        'A senha precisa ter pelo menos 6 caracteres.',
      ),
      // Código errado e código vencido chegam com o mesmo `otp_expired`
      // (FD-026, docs/002_conta_e_configuracoes/decisions.md): distingui-los
      // na tela diria a quem chuta se um código já foi válido algum dia.
      'otp_expired' => const ValidationFailure(
        'Código inválido ou vencido. Confira e digite de novo, ou volte '
        'para pedir um novo código.',
      ),
      'over_email_send_rate_limit' => const UnexpectedFailure(
        'Muitos pedidos em pouco tempo. Aguarde um instante e tente de novo.',
      ),
      'signup_disabled' => const PermissionFailure(
        'Cadastro por e-mail está desativado no momento.',
      ),
      _ => const UnexpectedFailure(),
    };
  }
}
