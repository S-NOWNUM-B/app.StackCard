import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/app_router.dart';
import 'core/theme/stackcard_theme.dart';

void main() {
  runApp(const StackCardApp());
}

class StackCardApp extends StatefulWidget {
  const StackCardApp({
    super.key,
    this.initialLocation = '/sign-in',
    this.initialThemeMode = ThemeMode.dark,
  });

  final String initialLocation;
  final ThemeMode initialThemeMode;

  @override
  State<StackCardApp> createState() => _StackCardAppState();
}

class _StackCardAppState extends State<StackCardApp> {
  late ThemeMode _themeMode = widget.initialThemeMode;
  late final GoRouter _router = createAppRouter(
    initialLocation: widget.initialLocation,
    themeMode: () => _themeMode,
    onThemeChanged: (mode) => setState(() => _themeMode = mode),
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StackCard',
      debugShowCheckedModeBanner: false,
      theme: StackCardTheme.light,
      darkTheme: StackCardTheme.dark,
      themeMode: _themeMode,
      themeAnimationDuration: Duration.zero,
      routerConfig: _router,
    );
  }
}
