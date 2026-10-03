import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/sign_in_screen.dart';
import '../features/home/home_screen.dart';
import '../features/portfolio/portfolio_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/settings/settings_screen.dart';
import '../shared/widgets/stackcard_states.dart';
import 'app_shell.dart';

GoRouter createAppRouter({
  required String initialLocation,
  required ThemeMode Function() themeMode,
  required ValueChanged<ThemeMode> onThemeChanged,
}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
    GoRoute(path: '/', redirect: (_, _) => '/home'),
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/portfolio', builder: (_, _) => const PortfolioScreen()),
        GoRoute(path: '/projects', builder: (_, _) => const ProjectsScreen()),
        GoRoute(
          path: '/settings',
          builder: (_, _) => SettingsScreen(
            themeMode: themeMode,
            onThemeChanged: onThemeChanged,
          ),
        ),
      ],
    ),
  ],
  errorBuilder: (context, _) => Scaffold(
    body: SafeArea(
      child: Center(
        child: StackCardStateView(
          kind: StackCardViewState.error,
          title: 'Экран не найден',
          message: 'Вернитесь на главную страницу демо.',
          onRetry: () => context.go('/home'),
        ),
      ),
    ),
  ),
);
