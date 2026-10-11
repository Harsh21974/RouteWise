import 'package:flutter/material.dart';

import 'shared/design_system/app_theme.dart';
import 'shared/navigation/app_shell.dart';

/// RouteWise driver app. Dark-mode-first shell; no backend wiring yet.
class RouteWiseApp extends StatelessWidget {
  const RouteWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RouteWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const AppShell(),
    );
  }
}