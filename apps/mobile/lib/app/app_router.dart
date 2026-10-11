import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_strings.dart';
import '../features/auth/auth.dart';
import '../features/github_import/github_import.dart';
import '../features/home/home_screen.dart';
import '../features/portfolio_draft/portfolio_draft.dart';
import '../features/projects/projects.dart';
import '../features/settings/settings_screen.dart';
import '../features/inbox/inbox.dart';
import '../features/notifications/notifications.dart';
import '../shared/widgets/stackcard_states.dart';
import 'app_shell.dart';

/// The router reads this gate without owning authentication or draft state.
class AppRouteAccess extends ChangeNotifier {
  bool configured = false;
  bool restoring = false;
  bool authenticated = false;
  bool guest = false;
  bool pendingAccountDeletion = false;
  bool authBusy = false;
  bool personalizationRequired = false;

  bool get canEdit => !configured || (!restoring && (authenticated || guest));

  void update({
    required bool configured,
    required bool restoring,
    required bool authenticated,
    required bool guest,
    bool pendingAccountDeletion = false,
    bool authBusy = false,
    bool personalizationRequired = false,
  }) {
    if (this.configured == configured &&
        this.restoring == restoring &&
        this.authenticated == authenticated &&
        this.guest == guest &&
        this.pendingAccountDeletion == pendingAccountDeletion &&
        this.authBusy == authBusy &&
        this.personalizationRequired == personalizationRequired) {
      return;
    }
    this.configured = configured;
    this.restoring = restoring;
    this.authenticated = authenticated;
    this.guest = guest;
    this.pendingAccountDeletion = pendingAccountDeletion;
    this.authBusy = authBusy;
    this.personalizationRequired = personalizationRequired;
    notifyListeners();
  }
}

String safeAuthDestination(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      uri.path.startsWith('//')) {
    return '/home';
  }
  final path = uri.path;
  if (path == '/home' ||
      path == '/editor' ||
      path == '/projects' ||
      path == '/settings' ||
      path == '/settings/appearance' ||
      path == '/settings/notifications' ||
      path == '/settings/github' ||
      path == '/settings/about' ||
      path == '/inbox' ||
      RegExp(r'^/inbox/[0-9a-f]{32}$').hasMatch(path) ||
      path == '/settings/account' ||
      path == '/personalization' ||
      path == '/portfolio/migrate' ||
      path == '/github-import' ||
      path == '/projects/new' ||
      RegExp(r'^/projects/[^/]+/edit$').hasMatch(path)) {
    return uri.toString();
  }
  if (path == '/resumes' ||
      path.startsWith('/resumes/') ||
      path == '/portfolio' ||
      path.startsWith('/portfolio/') ||
      path == '/portfolio-draft' ||
      path.startsWith('/settings/profile') ||
      path.startsWith('/settings/contacts') ||
      path == '/settings/privacy') {
    return '/editor';
  }
  return '/home';
}

GoRouter createAppRouter({
  required String initialLocation,
  AppRouteAccess? access,
}) => GoRouter(
  initialLocation: initialLocation,
  refreshListenable: access,
  redirect: (_, state) {
    final path = state.uri.path;
    final authForm = {
      '/sign-in',
      '/register',
      '/reset-password',
    }.contains(path);
    final accountOnly =
        path == '/inbox' ||
        path.startsWith('/inbox/') ||
        path == '/settings/notifications';
    if (accountOnly &&
        (access?.authenticated != true || access?.restoring == true)) {
      return Uri(
        path: '/sign-in',
        queryParameters: {'from': state.uri.toString()},
      ).toString();
    }
    if (access?.configured != true) return null;
    if (path == '/settings/account' &&
        access!.pendingAccountDeletion &&
        !access.restoring) {
      return null;
    }
    if (access!.authenticated &&
        !access.restoring &&
        !access.authBusy &&
        access.personalizationRequired &&
        path != '/personalization') {
      return '/personalization';
    }
    if (authForm || path == '/github-import') {
      if (authForm &&
          access.authenticated &&
          !access.restoring &&
          !access.authBusy) {
        return safeAuthDestination(state.uri.queryParameters['from']);
      }
      return null;
    }
    if (!access.canEdit) {
      return Uri(
        path: '/sign-in',
        queryParameters: {'from': state.uri.toString()},
      ).toString();
    }
    return null;
  },
  routes: [
    GoRoute(
      name: 'inbox',
      path: '/inbox',
      builder: (_, _) => const InboxScreen(),
      routes: [
        GoRoute(
          name: 'inboxRequest',
          path: ':requestId',
          builder: (_, state) =>
              InboxRequestScreen(requestId: state.pathParameters['requestId']!),
        ),
      ],
    ),
    GoRoute(
      name: 'signIn',
      path: '/sign-in',
      builder: (_, _) => const SignInScreen(),
    ),
    GoRoute(
      name: 'register',
      path: '/register',
      builder: (_, _) => const SignInScreen(mode: AuthFormMode.register),
    ),
    GoRoute(
      name: 'resetPassword',
      path: '/reset-password',
      builder: (_, _) => const SignInScreen(mode: AuthFormMode.resetPassword),
    ),
    GoRoute(
      name: 'githubImport',
      path: '/github-import',
      builder: (_, _) => const GitHubImportScreen(),
    ),
    GoRoute(
      name: 'personalization',
      path: '/personalization',
      builder: (_, _) => const PersonalizationScreen(),
    ),
    GoRoute(
      name: 'mainPortfolioMigration',
      path: '/portfolio/migrate',
      builder: (_, _) => const MainPortfolioMigrationScreen(),
    ),
    GoRoute(
      name: 'settings',
      path: '/settings',
      builder: (_, _) => const SettingsScreen(),
      routes: [
        GoRoute(
          name: 'settingsNotifications',
          path: 'notifications',
          builder: (_, _) => const NotificationsScreen(),
        ),
        GoRoute(
          name: 'settingsAppearance',
          path: 'appearance',
          builder: (_, _) => const SettingsAppearanceScreen(),
        ),
        GoRoute(
          name: 'settingsAccount',
          path: 'account',
          builder: (_, _) => const SettingsAccountScreen(),
        ),
        GoRoute(
          name: 'settingsGitHub',
          path: 'github',
          builder: (_, _) => const SettingsGitHubScreen(),
        ),
        GoRoute(
          name: 'settingsAbout',
          path: 'about',
          builder: (_, _) => const SettingsAboutScreen(),
        ),
        GoRoute(
          path: 'profile',
          redirect: (_, _) => '/editor',
          routes: [GoRoute(path: ':section', redirect: (_, _) => '/editor')],
        ),
        GoRoute(
          path: 'contacts',
          redirect: (_, _) => '/editor',
          routes: [GoRoute(path: 'links', redirect: (_, _) => '/editor')],
        ),
        GoRoute(path: 'privacy', redirect: (_, _) => '/editor'),
      ],
    ),
    GoRoute(path: '/portfolio-draft', redirect: (_, _) => '/editor'),
    GoRoute(
      path: '/portfolio/builder',
      redirect: (_, _) => '/editor',
      routes: [GoRoute(path: ':section', redirect: (_, _) => '/editor')],
    ),
    GoRoute(path: '/portfolio/preview', redirect: (_, _) => '/home'),
    GoRoute(
      name: 'newProject',
      path: '/projects/new',
      builder: (_, _) => const PortfolioProjectEditorScreen(),
    ),
    GoRoute(
      name: 'editProject',
      path: '/projects/:id/edit',
      builder: (_, state) =>
          PortfolioProjectEditorScreen(projectId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/', redirect: (_, _) => '/home'),
    // Старые deep links ведут в единственный редактор; архив остаётся в draft.
    GoRoute(
      path: '/resumes',
      redirect: (_, _) => '/editor',
      routes: [
        GoRoute(path: 'new', redirect: (_, _) => '/editor'),
        GoRoute(path: ':id/edit', redirect: (_, _) => '/editor'),
      ],
    ),
    GoRoute(
      path: '/portfolio',
      redirect: (_, _) => '/editor',
      routes: [
        GoRoute(path: 'new', redirect: (_, _) => '/editor'),
        GoRoute(path: ':id/edit', redirect: (_, _) => '/editor'),
      ],
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => FocusTraversalGroup(
        policy: _ShellBranchTraversalPolicy(),
        child: AppShell(
          location: state.uri.path,
          child: shell,
          onNavigate: (index) => shell.goBranch(index),
        ),
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'home',
              path: '/home',
              pageBuilder: (_, state) => _ShellBranchPage(
                key: state.pageKey,
                child: const HomeScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'projects',
              path: '/projects',
              pageBuilder: (_, state) => _ShellBranchPage(
                key: state.pageKey,
                child: const ProjectsScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'editor',
              path: '/editor',
              pageBuilder: (_, state) => _ShellBranchPage(
                key: state.pageKey,
                child: const MainPortfolioEditorScreen(),
              ),
            ),
          ],
        ),
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

class _ShellBranchPage extends Page<void> {
  const _ShellBranchPage({required super.key, required this.child});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => MaterialPageRoute<void>(
    settings: this,
    // Вкладка делит клавиатурную навигацию с панелями AppShell.
    // Диалоги и самостоятельные маршруты сохраняют собственный closed loop.
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
    builder: (routeContext) =>
        (ModalRoute.of<void>(routeContext)!.settings as _ShellBranchPage).child,
  );
}

class _ShellBranchTraversalPolicy extends ReadingOrderTraversalPolicy {
  // Flutter выбирает сам scope, если в нём нет доступных контролов.
  // У пустой главной disabled outputs не должны задерживать Tab/Shift-Tab.
  bool _empty(FocusNode node) =>
      node.nearestScope?.focusedChild == null &&
      node.nearestScope?.traversalDescendants.isEmpty == true;

  @override
  bool next(FocusNode currentNode) => _empty(currentNode)
      ? currentNode.nearestScope?.enclosingScope?.nextFocus() ?? false
      : super.next(currentNode);

  @override
  bool previous(FocusNode currentNode) => _empty(currentNode)
      ? currentNode.nearestScope?.enclosingScope?.previousFocus() ?? false
      : super.previous(currentNode);
}
