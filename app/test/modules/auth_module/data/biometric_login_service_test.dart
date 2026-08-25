import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/modules/auth_module/data/biometric_login_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _SupabaseClientMock extends Mock implements SupabaseClient {}

class _GoTrueClientMock extends Mock implements GoTrueClient {}

class _SecureStorageMock extends Mock implements FlutterSecureStorage {}

class _LocalAuthenticationMock extends Mock implements LocalAuthentication {}

void main() {
  const refreshTokenKey = 'biometric_refresh_token';
  const userIdKey = 'biometric_user_id';

  late _SupabaseClientMock client;
  late _GoTrueClientMock auth;
  late _SecureStorageMock storage;
  late LocalBiometricLoginService service;

  setUp(() {
    client = _SupabaseClientMock();
    auth = _GoTrueClientMock();
    storage = _SecureStorageMock();
    when(() => client.auth).thenReturn(auth);
    service = LocalBiometricLoginService(
      client,
      storage: storage,
      authenticator: _LocalAuthenticationMock(),
    );
  });

  test(
    'login por senha de outra conta descarta a credencial biométrica anterior',
    () async {
      final values = <String, String>{
        refreshTokenKey: 'refresh-token-da-conta-a',
        userIdKey: 'conta-a',
      };
      when(() => auth.currentSession).thenReturn(_sessionFor('conta-b'));
      when(() => storage.read(key: any(named: 'key'))).thenAnswer(
        (invocation) async => values[invocation.namedArguments[#key] as String],
      );
      when(() => storage.delete(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        values.remove(invocation.namedArguments[#key] as String);
      });

      await service.discardIfNotForCurrentSession();

      expect(values, isEmpty);
      verify(() => storage.delete(key: refreshTokenKey)).called(1);
      verify(() => storage.delete(key: userIdKey)).called(1);
    },
  );

  test('credencial sem conta vinculada não habilita a biometria', () async {
    when(() => storage.read(key: any(named: 'key'))).thenAnswer(
      (invocation) async =>
          invocation.namedArguments[#key] == refreshTokenKey ? 'legado' : null,
    );
    final authenticator = _LocalAuthenticationMock();
    when(() => authenticator.canCheckBiometrics).thenAnswer((_) async => true);
    when(
      () => authenticator.getAvailableBiometrics(),
    ).thenAnswer((_) async => [BiometricType.fingerprint]);
    service = LocalBiometricLoginService(
      client,
      storage: storage,
      authenticator: authenticator,
    );

    final status = await service.status();

    expect(status.isSupported, isTrue);
    expect(status.isEnabled, isFalse);
  });
}

Session _sessionFor(String userId) => Session(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  tokenType: 'bearer',
  user: User(
    id: userId,
    appMetadata: const {},
    userMetadata: null,
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  ),
);
