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
    this.categoryId,
    this.categoryName,
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
  final String? categoryId;
  final String? categoryName;

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
    categoryId,
    categoryName,
  ];
}
