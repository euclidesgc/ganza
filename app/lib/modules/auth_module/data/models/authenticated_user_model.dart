import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../domain/entities/authenticated_user.dart';

/// O `User` do supabase_flutter já vem tipado do SDK; o que falta é garantir
/// que os dois campos que o app usa existem antes de virar entidade.
abstract final class AuthenticatedUserModel {
  static AuthenticatedUser? fromSupabase(User? user) {
    if (user == null) return null;
    final email = user.email;
    if (email == null || email.isEmpty) return null;
    return AuthenticatedUser(id: user.id, email: email);
  }
}
