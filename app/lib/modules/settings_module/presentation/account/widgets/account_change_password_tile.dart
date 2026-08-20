import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../auth_module/auth_module.dart';
import '../../widgets/settings_section_tile.dart';

class AccountChangePasswordTile extends StatelessWidget {
  const AccountChangePasswordTile({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionTile(
      label: 'Trocar senha',
      onTap: () => context.pushNamed(AuthRoutes.changePasswordName),
    );
  }
}
