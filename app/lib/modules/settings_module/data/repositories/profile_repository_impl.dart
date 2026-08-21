import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_from_exception.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../models/profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, display_name, timezone';

  @override
  Future<Either<Failure, UserProfile>> getUserProfile() async {
    try {
      final session = _requireSession();
      if (session == null) return const Left(AuthFailure());

      final row = await _client
          .from('profiles')
          .select(_columns)
          .eq('id', session.id)
          .single();

      return ProfileModel.fromMap(row, email: session.email);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> updateDisplayName({
    required String displayName,
  }) async {
    try {
      final session = _requireSession();
      if (session == null) return const Left(AuthFailure());

      final row = await _client
          .from('profiles')
          .update({'display_name': displayName})
          .eq('id', session.id)
          .select(_columns)
          .single();

      return ProfileModel.fromMap(row, email: session.email);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  ({String id, String email})? _requireSession() {
    final user = _client.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) return null;
    return (id: user.id, email: email);
  }
}
