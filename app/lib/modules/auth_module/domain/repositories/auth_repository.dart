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

  Future<Either<Failure, Unit>> signUp({
    required String email,
    required String password,
  });

  Future<Either<Failure, Unit>> resetPasswordForEmail({required String email});

  Future<Either<Failure, Unit>> verifyRecoveryCode({
    required String email,
    required String token,
  });

  Future<Either<Failure, Unit>> updatePassword({required String newPassword});

  Future<Either<Failure, Unit>> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
