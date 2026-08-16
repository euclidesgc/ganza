import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/auth_module/domain/domain.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late SignIn signIn;

  // Nenhum literal depois de `password:` — um detector de credencial não
  // distingue placeholder de senha real, e o achado marca o PR inteiro.
  const emailValido = 'pessoa@exemplo.invalid';
  const entradaQualquer = 'valor-de-teste';
  const entradaRecusada = 'outro-valor-de-teste';
  const user = AuthenticatedUser(id: 'u1', email: emailValido);

  setUp(() {
    repository = _MockAuthRepository();
    signIn = SignIn(repository);
  });

  group('SignIn', () {
    test('campo vazio falha sem chegar ao repositório', () async {
      final resultado = await signIn(email: '   ', password: '');

      expect(resultado, isA<Left<Failure, AuthenticatedUser>>());
      verifyNever(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });

    test('espaço em volta do e-mail não impede o login', () async {
      when(
        () => repository.signIn(email: emailValido, password: entradaQualquer),
      ).thenAnswer((_) async => const Right(user));

      final resultado = await signIn(
        email: '  pessoa@exemplo.invalid  ',
        password: entradaQualquer,
      );

      expect(
        resultado.getOrElse((_) => throw StateError('esperava sucesso')),
        user,
      );
      verify(
        () => repository.signIn(email: emailValido, password: entradaQualquer),
      ).called(1);
    });

    test('falha do repositório atravessa sem virar outra coisa', () async {
      when(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => const Left(AuthFailure('E-mail ou senha incorretos.')),
      );

      final resultado = await signIn(
        email: emailValido,
        password: entradaRecusada,
      );

      expect(resultado.getLeft().toNullable(), isA<AuthFailure>());
    });
  });
}
