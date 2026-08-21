import 'package:flutter/material.dart';

/// O menu lateral da casca do app. Não conhece rota nem módulo: recebe os
/// destinos já prontos, cada um com seu callback de navegação embutido.
/// Aceita `Widget` — não só `DrawerNavigationItem` — porque um destino como
/// o chat decide seu próprio estado habilitado/desabilitado via cubit.
class GanzaDrawer extends StatelessWidget {
  const GanzaDrawer({super.key, required this.items, this.header});

  final Widget? header;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(child: ListView(children: [?header, ...items])),
    );
  }
}
