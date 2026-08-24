import 'package:equatable/equatable.dart';

class PayoffSimulation extends Equatable {
  const PayoffSimulation({
    required this.presentValue,
    required this.nominalTotal,
  });

  final int presentValue;
  final int nominalTotal;

  int get interestSaved => nominalTotal - presentValue;

  @override
  List<Object?> get props => [presentValue, nominalTotal];
}
