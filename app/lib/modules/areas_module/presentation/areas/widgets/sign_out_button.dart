import 'package:flutter/material.dart';

import '../../../../../core/theme/theme.dart';
import '../../../../../injection.dart';
import '../../../../auth_module/auth_module.dart';

class SignOutButton extends StatelessWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => getIt<SignOut>()(),
      icon: const Icon(AppIcons.signOut),
      tooltip: 'Sair',
    );
  }
}
