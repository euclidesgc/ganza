import 'package:equatable/equatable.dart';

import 'commitment_direction.dart';

class Commitment extends Equatable {
  const Commitment({
    required this.id,
    required this.name,
    required this.direction,
    required this.valueMode,
    required this.totalAmount,
    required this.installmentsTotal,
    required this.interestRateMonthly,
    required this.amortizationSystem,
    required this.outstandingBalance,
  });

  final String id;
  final String name;
  final CommitmentDirection direction;
  final String valueMode;
  final int? totalAmount;
  final int? installmentsTotal;
  final double? interestRateMonthly;
  final String? amortizationSystem;
  final int? outstandingBalance;

  @override
  List<Object?> get props => [
    id,
    name,
    direction,
    valueMode,
    totalAmount,
    installmentsTotal,
    interestRateMonthly,
    amortizationSystem,
    outstandingBalance,
  ];
}
