import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/format/money_formatter.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('formatMoney', () {
    test('formata centavos em reais', () {
      expect(formatMoney(4500), 'R\$ 45,00');
    });

    test('valor negativo usa o sinal de menos tipográfico', () {
      expect(formatMoney(-4500), '−R\$ 45,00');
    });

    test('valor grande agrupa milhar sem arredondar', () {
      expect(formatMoney(123456789), 'R\$ 1.234.567,89');
    });

    test('centavos com um dígito ganham zero à esquerda', () {
      expect(formatMoney(5), 'R\$ 0,05');
    });
  });
}
