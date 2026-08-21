import 'package:go_router/go_router.dart';

import 'presentation/chat/chat_page.dart';

abstract final class ChatRoutes {
  static const name = 'chat';
  static const path = '/chat';

  static GoRoute get route =>
      GoRoute(path: path, name: name, builder: ChatPage.pageBuilder);
}
