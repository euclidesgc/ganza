import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sem conexão com o servidor.']);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Não encontramos o que você pediu.']);
}

final class ValidationFailure extends Failure {
  const ValidationFailure([
    super.message = 'Os dados enviados não são válidos.',
  ]);
}

final class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Sua sessão expirou. Entre de novo.']);
}

final class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Você não tem acesso a isto.']);
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Algo deu errado. Tente de novo.']);
}
