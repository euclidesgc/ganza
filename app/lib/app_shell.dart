import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/theme.dart';
import 'core/widgets/widgets.dart';
import 'injection.dart';
import 'modules/auth_module/auth_module.dart';
import 'modules/settings_module/settings_module.dart';
import 'modules/transactions_module/transactions_module.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganzá'),
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Abrir menu',
            icon: const Icon(AppIcons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: GanzaDrawer(
        items: [
          DrawerNavigationItem(
            label: 'Transações',
            icon: AppIcons.transactions,
            onSelected: () => TransactionsRoutes.pushNamed(context),
          ),
          DrawerNavigationItem(
            label: 'Configurações',
            icon: AppIcons.settings,
            onSelected: () => context.pushNamed(SettingsRoutes.name),
          ),
          const DrawerNavigationItem(
            label: 'Chat',
            icon: AppIcons.chat,
            disabledReason: 'Chegando em breve.',
          ),
          DrawerNavigationItem(
            label: 'Sair',
            icon: AppIcons.signOut,
            onSelected: () => getIt<SignOut>()(),
          ),
        ],
      ),
      body: SafeArea(child: child),
    );
  }
}
