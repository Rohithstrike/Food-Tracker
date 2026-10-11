import 'package:flutter/cupertino.dart';

import 'app/app_shell.dart';
import 'core/design_system/app_theme.dart';

void main() {
  runApp(const IndianFoodTrackerApp());
}

/// Root of the application.
/// The theme follows the system light/dark appearance.
class IndianFoodTrackerApp extends StatelessWidget {
  const IndianFoodTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Indian Food Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const AppShell(),
    );
  }
}