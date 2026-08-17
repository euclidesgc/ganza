import 'package:equatable/equatable.dart';

import 'transaction_direction.dart';

class Transaction extends Equatable {
  const Transaction({
    required this.id,
    required this.areaId,
    required this.direction,
    required this.amount,
    required this.description,
    required this.occurredAt,
    required this.source,
    required this.reconciliationStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? areaId;
  final TransactionDirection direction;
  final int amount;
  final String description;
  final DateTime occurredAt;
  final String source;
  final String reconciliationStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction copyWith({
    String? id,
    String? Function()? areaId,
    TransactionDirection? direction,
    int? amount,
    String? description,
    DateTime? occurredAt,
    String? source,
    String? reconciliationStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      areaId: areaId != null ? areaId() : this.areaId,
      direction: direction ?? this.direction,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      occurredAt: occurredAt ?? this.occurredAt,
      source: source ?? this.source,
      reconciliationStatus: reconciliationStatus ?? this.reconciliationStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    areaId,
    direction,
    amount,
    description,
    occurredAt,
    source,
    reconciliationStatus,
    createdAt,
    updatedAt,
  ];
}
