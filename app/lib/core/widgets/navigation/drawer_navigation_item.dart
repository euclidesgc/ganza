import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Um destino do menu lateral. Quando [disabledReason] vem preenchido, o
/// item nasce apagado e mostra o motivo em texto — quem decide isso é quem
/// monta o menu (via construtor), nunca este widget.
class DrawerNavigationItem extends StatelessWidget {
  const DrawerNavigationItem({
    super.key,
    required this.label,
    required this.icon,
    this.onSelected,
    this.disabledReason,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onSelected;
  final String? disabledReason;

  bool get _isEnabled => disabledReason == null;

  @override
  Widget build(BuildContext context) {
    final reason = disabledReason;
    final semanticLabel = _isEnabled ? label : '$label. $reason';

    return Semantics(
      label: semanticLabel,
      button: _isEnabled,
      enabled: _isEnabled,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel,
        child: ListTile(
          enabled: _isEnabled,
          leading: Icon(
            icon,
            color: _isEnabled ? null : context.ganza.mutedInk,
          ),
          title: Text(label),
          subtitle: reason == null ? null : Text(reason),
          onTap: _isEnabled
              ? () {
                  Navigator.of(context).pop();
                  onSelected?.call();
                }
              : null,
        ),
      ),
    );
  }
}
