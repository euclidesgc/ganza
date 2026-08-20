import 'package:flutter/material.dart';

import 'drawer_navigation_item.dart';

/// O menu lateral da casca do app. Não conhece rota nem módulo: recebe os
/// destinos já prontos, cada um com seu callback de navegação embutido.
class GanzaDrawer extends StatelessWidget {
  const GanzaDrawer({super.key, required this.items, this.header});

  final Widget? header;
  final List<DrawerNavigationItem> items;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(child: ListView(children: [?header, ...items])),
    );
  }
}
