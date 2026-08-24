import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/format/date_formatter.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('formatTransactionDate', () {
    test('mesmo ano devolve dia/mês e dia da semana sem o sufixo', () {
      final date = DateTime(2026, 8, 14);
      final now = DateTime(2026, 8, 20);
      expect(formatTransactionDate(date, now: now), '14/08, sexta');
    });

    test('ano diferente inclui o ano', () {
      final date = DateTime(2025, 12, 15);
      final now = DateTime(2026, 1, 10);
      expect(formatTransactionDate(date, now: now), '15/12/2025, segunda');
    });

    test('sábado não perde o nome por não ter o sufixo -feira', () {
      final date = DateTime(2026, 8, 15);
      final now = DateTime(2026, 8, 20);
      expect(formatTransactionDate(date, now: now), '15/08, sábado');
    });
  });
}
