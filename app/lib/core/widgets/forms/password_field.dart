import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Campo de senha com revelação explícita e rótulos acessíveis.
///
/// O estado fica no próprio campo para que cada senha de um formulário possa
/// ser conferida sem expor as demais.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.label,
    this.fieldKey,
    this.autofillHints = const [AutofillHints.password],
    this.textInputAction = TextInputAction.done,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final Key? fieldKey;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  static const _showLabel = 'Mostrar senha';
  static const _hideLabel = 'Ocultar senha';

  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscured,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        suffixIcon: Semantics(
          label: _obscured ? _showLabel : _hideLabel,
          button: true,
          excludeSemantics: true,
          child: IconButton(
            onPressed: () => setState(() => _obscured = !_obscured),
            icon: Icon(_obscured ? AppIcons.revealSecret : AppIcons.hideSecret),
          ),
        ),
      ),
    );
  }
}
