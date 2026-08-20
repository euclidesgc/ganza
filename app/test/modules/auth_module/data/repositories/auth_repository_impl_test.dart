import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/auth_module/data/repositories/auth_repository_impl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late AuthRepositoryImpl repository;

  // Nenhum literal depois de `password:` — um detector de credencial não
  // distingue placeholder de senha real, e o achado marca o PR inteiro.
  const emailValido = 'pessoa@exemplo.invalid';
  const senhaQualquer = 'nao-e-uma-senha-real';

  setUpAll(() {
    registerFallbackValue(OtpType.recovery);
  });

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    when(() => client.auth).thenReturn(auth);
    repository = AuthRepositoryImpl(client);
  });

  group('AuthRepositoryImpl.signUp', () {
    test(
      'GoTrue devolvendo user_already_exists produz o mesmo Right(unit) do cadastro novo — '
      'endereço repetido não pode virar Failure distinguível',
      () async {
        when(
          () => auth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const AuthException(
            'A user with this email address has already been registered',
            code: 'user_already_exists',
          ),
        );

        final resultado = await repository.signUp(
          email: emailValido,
          password: senhaQualquer,
        );

        expect(resultado, const Right<Failure, Unit>(unit));
      },
    );

    test('cadastro sem erro devolve o mesmo Right(unit)', () async {
      when(
        () => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse());

      final resultado = await repository.signUp(
        email: emailValido,
        password: senhaQualquer,
      );

      expect(resultado, const Right<Failure, Unit>(unit));
    });

    test('outro código de erro continua virando Failure', () async {
      when(
        () => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const AuthException(
          'Password should be at least 6 characters.',
          code: 'weak_password',
        ),
      );

      final resultado = await repository.signUp(
        email: emailValido,
        password: senhaQualquer,
      );

      expect(resultado.getLeft().toNullable(), isA<ValidationFailure>());
    });
  });

  group('AuthRepositoryImpl.resetPasswordForEmail', () {
    // over_email_send_rate_limit só dispara quando o GoTrue de fato envia
    // e-mail: para endereço sem conta o pedido nunca esbarra nesse limite,
    // então revelar essa mensagem na segunda tentativa distinguiria conta
    // existente de inexistente (FD-028,
    // docs/002_conta_e_configuracoes/decisions.md).
    test(
      'GoTrue devolvendo over_email_send_rate_limit produz o mesmo Right(unit) '
      'do pedido sem erro — segunda tentativa não pode virar Failure distinguível',
      () async {
        when(
          () => auth.resetPasswordForEmail(any()),
        ).thenThrow(
          const AuthException(
            'For security purposes, you can only request this after 46 seconds.',
            code: 'over_email_send_rate_limit',
          ),
        );

        final resultado = await repository.resetPasswordForEmail(
          email: emailValido,
        );

        expect(resultado, const Right<Failure, Unit>(unit));
      },
    );

    test('pedido sem erro devolve o mesmo Right(unit)', () async {
      when(() => auth.resetPasswordForEmail(any())).thenAnswer((_) async {});

      final resultado = await repository.resetPasswordForEmail(
        email: emailValido,
      );

      expect(resultado, const Right<Failure, Unit>(unit));
    });

    test('outro código de erro continua virando Failure', () async {
      when(
        () => auth.resetPasswordForEmail(any()),
      ).thenThrow(
        const AuthException(
          'Email rate limit exceeded',
          code: 'over_request_rate_limit',
        ),
      );

      final resultado = await repository.resetPasswordForEmail(
        email: emailValido,
      );

      expect(resultado.getLeft().toNullable(), isA<UnexpectedFailure>());
    });
  });

  group('AuthRepositoryImpl.verifyRecoveryCode', () {
    // otp_expired cobre código errado e código vencido ao mesmo tempo
    // (FD-026, docs/002_conta_e_configuracoes/decisions.md) — não há como
    // testar os dois separadamente porque o GoTrue não os separa.
    test('código errado ou vencido devolve a mensagem que orienta a corrigir, '
        'não a genérica de erro inesperado', () async {
      when(
        () => auth.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: any(named: 'type'),
        ),
      ).thenThrow(
        const AuthException(
          'Token has expired or is invalid',
          code: 'otp_expired',
        ),
      );

      final resultado = await repository.verifyRecoveryCode(
        email: emailValido,
        token: '000000',
      );

      expect(
        resultado,
        const Left<Failure, Unit>(
          ValidationFailure(
            'Código inválido ou vencido. Confira e digite de novo, ou '
            'volte para pedir um novo código.',
          ),
        ),
      );
    });
  });
}
