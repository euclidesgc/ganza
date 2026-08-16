import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/authenticated_user.dart';

abstract interface class AuthRepository {
  Stream<AuthenticatedUser?> observeCurrentUser();

  AuthenticatedUser? get currentUser;

  Future<Either<Failure, AuthenticatedUser>> signIn({
    required String email,
    required String password,
  });

  Future<Either<Failure, Unit>> signOut();
}
