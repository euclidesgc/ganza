import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/widgets.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      const ChatPage();

  @override
  Widget build(BuildContext context) => const PlaceholderBody(title: 'Chat');
}
