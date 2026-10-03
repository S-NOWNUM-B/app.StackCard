import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_strings.dart';
import '../features/auth/auth.dart';
import '../features/github_import/github_import.dart';
import '../features/home/home_screen.dart';
import '../features/portfolio/portfolio.dart';
import '../features/portfolio_draft/portfolio_draft.dart';
import '../features/projects/projects.dart';
import '../features/settings/settings_screen.dart';
import '../shared/widgets/stackcard_states.dart';
import 'app_shell.dart';

GoRouter createAppRouter({required String initialLocation}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
    GoRoute(
      path: '/github-import',
      builder: (_, _) => const GitHubImportScreen(),
    ),
    GoRoute(
      path: '/portfolio-draft',
      builder: (_, _) => const PortfolioDraftScreen(),
    ),
    GoRoute(path: '/', redirect: (_, _) => '/home'),
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/portfolio', builder: (_, _) => const PortfolioScreen()),
        GoRoute(path: '/projects', builder: (_, _) => const ProjectsScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ],
    ),
  ],
  errorBuilder: (context, _) => Scaffold(
    body: SafeArea(
      child: Center(
        child: StackCardStateView(
          kind: StackCardViewState.error,
          title: context.strings.tr('router.notFound'),
          message: context.strings.tr('router.notFoundHint'),
          onRetry: () => context.go('/home'),
        ),
      ),
    ),
  ),
);
