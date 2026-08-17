import 'package:intl/intl.dart';

const _minusSign = '−';

/// `amount` chega como centavos (`int`) do banco ao teclado — nunca `double`.
/// Uma soma de valores em ponto flutuante não fecha exata, e o erro só
/// aparece meses depois, num total que não bate.
String formatMoney(int cents) {
  final isNegative = cents.isNegative;
  final absoluteCents = cents.abs();
  final units = absoluteCents ~/ 100;
  final remainder = absoluteCents % 100;

  final groupedUnits = NumberFormat.decimalPattern('pt_BR').format(units);
  final remainderLabel = remainder.toString().padLeft(2, '0');
  final sign = isNegative ? _minusSign : '';

  return '${sign}R\$ $groupedUnits,$remainderLabel';
}
