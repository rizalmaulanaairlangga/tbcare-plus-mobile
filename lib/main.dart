import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppRoutes.navigatorKey,
      title: 'TB Care Plus',
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.cover,
      onGenerateRoute: (settings) {
        final builder = AppRoutes.routes[settings.name];
        if (builder != null) {
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (context, animation, secondaryAnimation) =>
                builder(context),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          );
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
