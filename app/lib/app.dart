import 'package:flutter/material.dart';

import 'app_router.dart';
import 'core/theme/app_theme.dart';

class GanzaApp extends StatefulWidget {
  const GanzaApp({super.key});

  @override
  State<GanzaApp> createState() => _GanzaAppState();
}

class _GanzaAppState extends State<GanzaApp> {
  late final _router = createRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ganzá',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
