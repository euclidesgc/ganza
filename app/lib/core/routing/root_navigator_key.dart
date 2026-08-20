import 'package:flutter/widgets.dart';

/// Chave compartilhada entre `app_router.dart` e as rotas de módulo que
/// precisam escapar do `ShellRoute`: um destino sob `/configuracoes/`
/// referencia esta mesma chave em `parentNavigatorKey` para renderizar no
/// Navigator raiz, com `AppBar` e botão de voltar em vez do drawer do shell.
final rootNavigatorKey = GlobalKey<NavigatorState>();
