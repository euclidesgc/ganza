import 'package:flutter/material.dart';

import '../../theme/theme.dart';

class SecretField extends StatefulWidget {
  const SecretField({
    required this.label,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final bool enabled;

  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> {
  bool _obscured = true;

  void _toggleObscured() {
    setState(() {
      _obscured = !_obscured;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      obscureText: _obscured,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        prefixIcon: Icon(AppIcons.apiKey),
        suffixIcon: Semantics(
          label: _obscured ? 'Mostrar a chave' : 'Ocultar a chave',
          button: true,
          excludeSemantics: true,
          child: IconButton(
            onPressed: _toggleObscured,
            icon: Icon(_obscured ? AppIcons.revealSecret : AppIcons.hideSecret),
          ),
        ),
      ),
    );
  }
}
