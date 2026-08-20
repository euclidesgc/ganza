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
}
