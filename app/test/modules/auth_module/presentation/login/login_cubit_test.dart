import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/core/session/session.dart';
import 'package:ganza/modules/auth_module/domain/entities/authenticated_user.dart';
import 'package:ganza/modules/auth_module/domain/entities/biometric_login_status.dart';
import 'package:ganza/modules/auth_module/domain/repositories/auth_repository.dart';
import 'package:ganza/modules/auth_module/domain/repositories/biometric_login_service.dart';
import 'package:ganza/modules/auth_module/domain/usecases/sign_in.dart';
import 'package:ganza/modules/auth_module/presentation/login/login_cubit.dart';
import 'package:mocktail/mocktail.dart';

class _AuthRepositoryMock extends Mock implements AuthRepository {}

class _BiometricLoginFake implements BiometricLoginService {
  var enableCalls = 0;
  var discardCalls = 0;
  Either<Failure, AuthenticatedUser> biometricResult = const Left(
    AuthFailure(),
  );

  @override
  Future<void> enableForCurrentSession() async => enableCalls++;

  @override
  Future<void> disable() async {}

  @override
  Future<void> discardIfNotForCurrentSession() async => discardCalls++;

  @override
  Future<void> refreshCurrentSessionIfEnabled() async {}

  @override
  Future<Either<Failure, AuthenticatedUser>> signIn() async => biometricResult;

  @override
  Future<BiometricLoginStatus> status() async =>
      const BiometricLoginStatus(isSupported: true, isEnabled: true);
}

void main() {
  const user = AuthenticatedUser(id: 'u1', email: 'euclides@ganza.test');

  group('LoginCubit', () {
    late _AuthRepositoryMock repository;
    late _BiometricLoginFake biometrics;

    setUp(() {
      repository = _AuthRepositoryMock();
      biometrics = _BiometricLoginFake();
    });

    LoginCubit createCubit() =>
        LoginCubit(SignIn(repository), LastSignedInEmail(), biometrics);

    blocTest<LoginCubit, LoginState>(
      'guarda acesso biométrico somente após login por senha bem-sucedido',
      build: () {
        when(
          () => repository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => const Right(user));
        return createCubit();
      },
      act: (cubit) => cubit.signIn(
        email: user.email,
        password: 'senha-placeholder',
        enableBiometrics: true,
      ),
      expect: () => [const LoginInProgress(), const LoginSucceeded(user)],
      verify: (_) => expect(biometrics.enableCalls, 1),
    );

    blocTest<LoginCubit, LoginState>(
      'usa o resultado da autenticação biométrica para entrar',
      build: () {
        biometrics.biometricResult = const Right(user);
        return createCubit();
      },
      act: (cubit) => cubit.signInWithBiometrics(),
      expect: () => [const LoginInProgress(), const LoginSucceeded(user)],
    );

    blocTest<LoginCubit, LoginState>(
      'remove a credencial biométrica de outra conta quando a nova não consentiu',
      build: () {
        when(
          () => repository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => const Right(user));
        return createCubit();
      },
      act: (cubit) =>
          cubit.signIn(email: user.email, password: 'senha-placeholder'),
      expect: () => [const LoginInProgress(), const LoginSucceeded(user)],
      verify: (_) {
        expect(biometrics.discardCalls, 1);
        expect(biometrics.enableCalls, 0);
      },
    );
  });
}
