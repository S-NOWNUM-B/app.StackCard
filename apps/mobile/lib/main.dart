import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app/app_router.dart';
import 'core/state/appearance_controller.dart';
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
  late final GoRouter _router = createAppRouter(
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return riverpod.ProviderScope(
      child: ChangeNotifierProvider(
        create: (_) => AppearanceController(themeMode: widget.initialThemeMode),
        child: Selector<AppearanceController, ThemeMode>(
          selector: (_, controller) => controller.themeMode,
          builder: (context, themeMode, _) => MaterialApp.router(
            title: 'StackCard',
            debugShowCheckedModeBanner: false,
            theme: StackCardTheme.light,
            darkTheme: StackCardTheme.dark,
            themeMode: themeMode,
            themeAnimationDuration: Duration.zero,
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}
