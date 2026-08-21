import 'package:go_router/go_router.dart';

import '../../core/routing/routing.dart';
import 'presentation/account/settings_account_page.dart';
import 'presentation/ai/settings_ai_page.dart';
import 'presentation/bank/settings_bank_page.dart';
import 'presentation/settings_home/settings_home_page.dart';

abstract final class SettingsRoutes {
  static const name = 'configuracoes';
  static const path = '/configuracoes';

  static const accountName = 'configuracoes-conta';
  static const accountPath = 'conta';

  static const aiName = 'configuracoes-ia';
  static const aiPath = 'ia';
  static const aiFullPath = '$path/$aiPath';

  static const bankName = 'configuracoes-banco';
  static const bankPath = 'banco';

  static GoRoute get route => GoRoute(
    path: path,
    name: name,
    builder: SettingsHomePage.pageBuilder,
    routes: [
      GoRoute(
        path: accountPath,
        name: accountName,
        parentNavigatorKey: rootNavigatorKey,
        builder: SettingsAccountPage.pageBuilder,
      ),
      GoRoute(
        path: aiPath,
        name: aiName,
        parentNavigatorKey: rootNavigatorKey,
        builder: SettingsAiPage.pageBuilder,
      ),
      GoRoute(
        path: bankPath,
        name: bankName,
        parentNavigatorKey: rootNavigatorKey,
        builder: SettingsBankPage.pageBuilder,
      ),
    ],
  );
}
