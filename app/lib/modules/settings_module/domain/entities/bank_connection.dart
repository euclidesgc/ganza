import 'package:equatable/equatable.dart';

import 'bank_connection_status.dart';

class BankConnection extends Equatable {
  const BankConnection({
    required this.id,
    required this.institution,
    required this.status,
    required this.lastSyncedAt,
  });

  final String id;
  final String institution;
  final BankConnectionStatus status;
  final DateTime? lastSyncedAt;

  BankConnection copyWith({
    String? id,
    String? institution,
    BankConnectionStatus? status,
    DateTime? Function()? lastSyncedAt,
  }) {
    return BankConnection(
      id: id ?? this.id,
      institution: institution ?? this.institution,
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt != null ? lastSyncedAt() : this.lastSyncedAt,
    );
  }

  @override
  List<Object?> get props => [id, institution, status, lastSyncedAt];
}
