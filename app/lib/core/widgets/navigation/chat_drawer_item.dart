import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../session/session.dart';
import '../../theme/theme.dart';
import 'drawer_navigation_item.dart';

class ChatDrawerItem extends StatelessWidget {
  const ChatDrawerItem({super.key, required this.onSelected});

  final VoidCallback onSelected;

  static const _disabledReason = 'Configure a IA para usar o chat.';

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CapabilitiesCubit, CapabilitiesState, bool>(
      selector: (state) => state.capabilities.aiConfigured,
      builder: (context, aiConfigured) => DrawerNavigationItem(
        label: 'Chat',
        icon: AppIcons.chat,
        onSelected: aiConfigured ? onSelected : null,
        disabledReason: aiConfigured ? null : _disabledReason,
      ),
    );
  }
}
