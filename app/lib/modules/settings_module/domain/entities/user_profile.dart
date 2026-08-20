import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.timezone,
  });

  final String id;
  final String email;
  final String? displayName;
  final String timezone;

  UserProfile copyWith({
    String? id,
    String? email,
    String? Function()? displayName,
    String? timezone,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName != null ? displayName() : this.displayName,
      timezone: timezone ?? this.timezone,
    );
  }

  @override
  List<Object?> get props => [id, email, displayName, timezone];
}
