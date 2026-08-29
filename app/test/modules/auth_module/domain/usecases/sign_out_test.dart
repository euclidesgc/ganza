import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/auth_module/domain/repositories/auth_repository.dart';
import 'package:ganza/modules/auth_module/domain/repositories/biometric_login_service.dart';
import 'package:ganza/modules/auth_module/domain/usecases/sign_out.dart';
import 'package:mocktail/mocktail.dart';

class _AuthRepositoryMock extends Mock implements AuthRepository {}

class _BiometricLoginMock extends Mock implements BiometricLoginService {}

void main() {
  test(
    'logout global permanece bem-sucedido se o cofre não puder ser limpo',
    () async {
      final repository = _AuthRepositoryMock();
      final biometrics = _BiometricLoginMock();
      when(
        () => repository.signOut(),
      ).thenAnswer((_) async => const Right(unit));
      when(
        () => biometrics.disable(),
      ).thenThrow(StateError('cofre indisponível'));
      final signOut = SignOut(repository, biometrics);

      final result = await signOut();

      expect(result, const Right<Failure, Unit>(unit));
      verifyInOrder([() => repository.signOut(), () => biometrics.disable()]);
    },
  );
}
