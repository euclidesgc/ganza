import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/session/session.dart';
import 'core/theme/theme.dart';
import 'core/widgets/widgets.dart';
import 'injection.dart';
import 'modules/areas_module/areas_module.dart';
import 'modules/auth_module/auth_module.dart';
import 'modules/chat_module/chat_module.dart';
import 'modules/commitments_module/commitments_module.dart';
import 'modules/routines_module/routines_module.dart';
import 'modules/settings_module/settings_module.dart';
import 'modules/transactions_module/transactions_module.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CapabilitiesCubit>.value(
      value: getIt<CapabilitiesCubit>(),
      child: Scaffold(
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
              label: 'Início',
              icon: AppIcons.home,
              onSelected: () => AreasRoutes.goNamed(context),
            ),
            DrawerNavigationItem(
              label: 'Transações',
              icon: AppIcons.transactions,
              onSelected: () => TransactionsRoutes.pushNamed(context),
            ),
            DrawerNavigationItem(
              label: 'Rotinas',
              icon: AppIcons.dateField,
              onSelected: () => RoutinesRoutes.pushNamed(context),
            ),
            DrawerNavigationItem(
              label: 'Compromissos',
              icon: AppIcons.bank,
              onSelected: () => CommitmentsRoutes.pushNamed(context),
            ),
            DrawerNavigationItem(
              label: 'Configurações',
              icon: AppIcons.settings,
              onSelected: () => context.pushNamed(SettingsRoutes.name),
            ),
            ChatDrawerItem(
              onSelected: () => context.pushNamed(ChatRoutes.name),
            ),
            DrawerNavigationItem(
              label: 'Sair',
              icon: AppIcons.signOut,
              onSelected: () => getIt<SignOutLocally>()(),
            ),
          ],
        ),
        body: SafeArea(child: child),
      ),
    );
  }
}
