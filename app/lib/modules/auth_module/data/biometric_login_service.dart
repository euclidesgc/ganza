import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpdart/fpdart.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/failure_from_exception.dart';
import '../domain/entities/authenticated_user.dart';
import 'models/authenticated_user_model.dart';

class BiometricLoginStatus {
  const BiometricLoginStatus({
    required this.isSupported,
    required this.isEnabled,
  });

  final bool isSupported;
  final bool isEnabled;
}

abstract interface class BiometricLoginService {
  Future<BiometricLoginStatus> status();

  /// Guarda apenas o refresh token, cifrado pelo armazenamento seguro nativo.
  /// A senha nunca é persistida pelo app.
  Future<void> enableForCurrentSession();

  /// Atualiza o token salvo somente quando a pessoa já optou pela biometria.
  Future<void> refreshCurrentSessionIfEnabled();

  /// Descarta a credencial se ela tiver sido criada por outra conta.
  ///
  /// Um login por senha não transfere a opção biométrica entre contas no
  /// mesmo aparelho: a nova conta precisa consentir explicitamente.
  Future<void> discardIfNotForCurrentSession();

  Future<void> disable();

  Future<Either<Failure, AuthenticatedUser>> signIn();
}

class LocalBiometricLoginService implements BiometricLoginService {
  LocalBiometricLoginService(
    this._client, {
    LocalAuthentication? authenticator,
    FlutterSecureStorage? storage,
  }) : _authenticator = authenticator ?? LocalAuthentication(),
       _storage = storage ?? const FlutterSecureStorage();

  static const _refreshTokenKey = 'biometric_refresh_token';
  static const _userIdKey = 'biometric_user_id';

  final SupabaseClient _client;
  final LocalAuthentication _authenticator;
  final FlutterSecureStorage _storage;

  @override
  Future<BiometricLoginStatus> status() async {
    final supported = await _hasEnrolledBiometrics();
    if (!supported) {
      return const BiometricLoginStatus(isSupported: false, isEnabled: false);
    }
    final credential = await _readCredential();
    return BiometricLoginStatus(
      isSupported: true,
      isEnabled: credential != null,
    );
  }

  @override
  Future<void> enableForCurrentSession() async {
    final session = _client.auth.currentSession;
    final refreshToken = session?.refreshToken;
    if (session == null || refreshToken == null || refreshToken.isEmpty) {
      throw StateError('Não existe sessão para ativar a biometria.');
    }
    // O token e seu dono são gravados juntos na mesma operação lógica. A
    // presença do ID é obrigatória para nunca reutilizar um token legado ou
    // pertencente a outra conta após uma troca de usuário.
    await _storage.write(key: _userIdKey, value: session.user.id);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  @override
  Future<void> refreshCurrentSessionIfEnabled() async {
    final credential = await _readCredential();
    if (credential == null) return;
    if (credential.userId != _client.auth.currentSession?.user.id) {
      await disable();
      return;
    }
    await enableForCurrentSession();
  }

  @override
  Future<void> discardIfNotForCurrentSession() async {
    final credential = await _readCredential();
    if (credential == null) return;
    if (credential.userId != _client.auth.currentSession?.user.id) {
      await disable();
    }
  }

  @override
  Future<void> disable() async {
    // Tenta ambas as chaves mesmo se uma delas falhar; o chamador decide se a
    // limpeza local é relevante para o seu fluxo.
    await Future.wait([
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _userIdKey),
    ]);
  }

  @override
  Future<Either<Failure, AuthenticatedUser>> signIn() async {
    try {
      final credential = await _readCredential();
      if (credential == null) {
        return const Left(
          AuthFailure('Ative o login por digital ao entrar com sua senha.'),
        );
      }
      if (!await _hasEnrolledBiometrics()) {
        return const Left(
          AuthFailure('Nenhuma digital está configurada neste aparelho.'),
        );
      }

      final authenticated = await _authenticator.authenticate(
        localizedReason: 'Confirme sua digital para entrar no Ganzá.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (!authenticated) {
        return const Left(
          AuthFailure('A autenticação por digital foi cancelada.'),
        );
      }

      final response = await _client.auth.setSession(credential.refreshToken);
      final user = AuthenticatedUserModel.fromSupabase(response.user);
      if (user == null || user.id != credential.userId) {
        // A associação registrada no cofre é uma segunda barreira contra
        // dados parciais/corrompidos. A sessão recém-aberta não pode ficar
        // ativa se ela não corresponde à conta que consentiu a biometria.
        await _client.auth.signOut(scope: SignOutScope.local);
        await disable();
        return const Left(
          AuthFailure('Não foi possível entrar com a digital. Tente de novo.'),
        );
      }
      return Right(user);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  Future<bool> _hasEnrolledBiometrics() async {
    try {
      if (!await _authenticator.canCheckBiometrics) return false;
      return (await _authenticator.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      // Plataformas sem plugin (por exemplo, Web) não oferecem esse atalho de
      // login; o formulário de senha continua sendo o caminho disponível.
      return false;
    }
  }

  Future<_BiometricCredential?> _readCredential() async {
    final values = await Future.wait([
      _storage.read(key: _refreshTokenKey),
      _storage.read(key: _userIdKey),
    ]);
    final refreshToken = values[0];
    final userId = values[1];
    if (refreshToken == null ||
        refreshToken.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      return null;
    }
    return _BiometricCredential(refreshToken: refreshToken, userId: userId);
  }
}

class _BiometricCredential {
  const _BiometricCredential({
    required this.refreshToken,
    required this.userId,
  });

  final String refreshToken;
  final String userId;
}
