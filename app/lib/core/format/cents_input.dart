/// Acumula os dígitos que o usuário digita, dígito a dígito, entrando pela
/// direita — nunca `double.parse(x) * 100`. Ponto flutuante arredonda 45,00
/// para algo como 4499,999999999999, e o erro só aparece meses depois, num
/// total que não bate.
class CentsInput {
  const CentsInput([this.cents = 0]);

  final int cents;

  /// specs.md §6.1: campo de valor aceita no máximo 9 dígitos de reais.
  static const _maxCents = 99999999999;

  CentsInput appendDigit(int digit) {
    final next = cents * 10 + digit;
    return next > _maxCents ? this : CentsInput(next);
  }

  CentsInput backspace() => CentsInput(cents ~/ 10);

  @override
  bool operator ==(Object other) => other is CentsInput && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;
}
