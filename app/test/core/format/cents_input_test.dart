import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/format/cents_input.dart';

void main() {
  group('CentsInput', () {
    test('acumula dígitos em centavos inteiros, dígito a dígito', () {
      var input = const CentsInput();
      for (final digit in '4500'.split('')) {
        input = input.appendDigit(int.parse(digit));
      }
      expect(input.cents, 4500);
    });

    test('backspace descarta o último dígito', () {
      expect(const CentsInput(4500).backspace().cents, 450);
    });

    test('rejeita o dígito que estouraria o teto de 9 dígitos de reais', () {
      const atMax = CentsInput(99999999999);
      expect(atMax.appendDigit(9).cents, 99999999999);
    });

    test('é comparável por valor', () {
      expect(const CentsInput(4500), const CentsInput(4500));
    });
  });
}
