import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/session/session.dart';
import 'package:ganza/modules/auth_module/domain/domain.dart';
import 'package:ganza/modules/auth_module/presentation/password_recovery/password_recovery_code_cubit.dart';
import 'package:mocktail/mocktail.dart';

class _MockVerifyRecoveryCode extends Mock implements VerifyRecoveryCode {}

class _MockUpdatePassword extends Mock implements UpdatePassword {}

class _MockSignOut extends Mock implements SignOut {}

class _MockPasswordRecoveryScope extends Mock
    implements PasswordRecoveryScope {}

void main() {
  late _MockVerifyRecoveryCode verifyRecoveryCode;
  late _MockUpdatePassword updatePassword;
  late _MockSignOut signOut;
  late _MockPasswordRecoveryScope recoveryScope;

  PasswordRecoveryCodeCubit build() => PasswordRecoveryCodeCubit(
    verifyRecoveryCode,
    updatePassword,
    signOut,
    recoveryScope,
  );

  setUp(() {
    verifyRecoveryCode = _MockVerifyRecoveryCode();
    updatePassword = _MockUpdatePassword();
    signOut = _MockSignOut();
    recoveryScope = _MockPasswordRecoveryScope();
    when(() => signOut()).thenAnswer((_) async => const Right(unit));
  });

  group('signOutWithoutChangingPassword', () {
    test(
      'encerra a sessão antes de desligar o escopo, sem tocar a troca de senha',
      () async {
        final cubit = build();

        await cubit.signOutWithoutChangingPassword();

        verifyInOrder([() => signOut(), () => recoveryScope.end()]);
        verifyNever(
          () => updatePassword(newPassword: any(named: 'newPassword')),
        );
      },
    );
  });
}
