import 'package:equatable/equatable.dart';

class AuthenticatedUser extends Equatable {
  const AuthenticatedUser({required this.id, required this.email});

  final String id;
  final String email;

  @override
  List<Object?> get props => [id, email];
}
