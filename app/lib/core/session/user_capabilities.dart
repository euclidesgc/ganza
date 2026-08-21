import 'package:equatable/equatable.dart';

class UserCapabilities extends Equatable {
  const UserCapabilities({
    required this.aiConfigured,
    required this.bankConnected,
  });

  const UserCapabilities.unresolved()
    : aiConfigured = false,
      bankConnected = false;

  final bool aiConfigured;
  final bool bankConnected;

  @override
  List<Object?> get props => [aiConfigured, bankConnected];
}
