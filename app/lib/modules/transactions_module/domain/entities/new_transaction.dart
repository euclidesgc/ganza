import 'package:equatable/equatable.dart';

import 'transaction_direction.dart';

class NewTransaction extends Equatable {
  const NewTransaction({
    required this.direction,
    required this.amount,
    required this.description,
    required this.occurredAt,
  });

  final TransactionDirection direction;
  final int amount;
  final String description;
  final DateTime occurredAt;

  NewTransaction copyWith({
    TransactionDirection? direction,
    int? amount,
    String? description,
    DateTime? occurredAt,
  }) {
    return NewTransaction(
      direction: direction ?? this.direction,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }

  @override
  List<Object?> get props => [direction, amount, description, occurredAt];
}
