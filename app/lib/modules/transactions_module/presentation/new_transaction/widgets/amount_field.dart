import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/format/cents_input.dart';
import '../../../../../core/format/format.dart';
import '../../../../../core/theme/theme.dart';

class _CentsAmountFormatter extends TextInputFormatter {
  _CentsAmountFormatter({required this.onChanged});

  final ValueChanged<int> onChanged;
  CentsInput _value = const CentsInput();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldDigitCount = _digitsOnly(oldValue.text).length;
    final newDigits = _digitsOnly(newValue.text);
    final removedDigits = oldDigitCount - newDigits.length;

    var next = _value;
    if (removedDigits > 0) {
      for (var i = 0; i < removedDigits; i++) {
        next = next.backspace();
      }
    } else {
      final appendedDigits = newDigits.length > oldDigitCount
          ? newDigits.substring(oldDigitCount)
          : '';
      for (final digit in appendedDigits.split('')) {
        next = next.appendDigit(int.parse(digit));
      }
    }

    _value = next;
    onChanged(next.cents);

    final formatted = formatMoney(next.cents);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _digitsOnly(String text) =>
      text.replaceAll(RegExp(r'[^0-9]'), '');
}

class AmountField extends StatefulWidget {
  const AmountField({required this.onChanged, super.key});

  final ValueChanged<int> onChanged;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  late final TextEditingController _controller;
  late final _CentsAmountFormatter _formatter;

  @override
  void initState() {
    super.initState();
    _formatter = _CentsAmountFormatter(onChanged: widget.onChanged);
    _controller = TextEditingController(text: formatMoney(0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: 'Valor da transação',
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.right,
        textInputAction: TextInputAction.next,
        style: AppTypography.valorGrande.copyWith(
          color: context.colors.onSurface,
        ),
        inputFormatters: [_formatter],
        decoration: const InputDecoration(labelText: 'Valor'),
      ),
    );
  }
}
