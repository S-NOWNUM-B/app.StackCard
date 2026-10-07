import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_strings.dart';
import '../features/auth/auth.dart';
import '../features/github_import/github_import.dart';
import '../features/home/home_screen.dart';
import '../features/portfolio_draft/portfolio_draft.dart';
import '../features/projects/projects.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/developer_profile_screen.dart';
import '../shared/widgets/stackcard_states.dart';
import 'app_shell.dart';

/// The router reads this gate without owning authentication or draft state.
class AppRouteAccess extends ChangeNotifier {
  bool configured = false;
  bool restoring = false;
  bool authenticated = false;
  bool guest = false;

  bool get canEdit => !configured || (!restoring && (authenticated || guest));

  void update({
    required bool configured,
    required bool restoring,
    required bool authenticated,
    required bool guest,
  }) {
    if (this.configured == configured &&
        this.restoring == restoring &&
        this.authenticated == authenticated &&
        this.guest == guest) {
      return;
    }
    this.configured = configured;
    this.restoring = restoring;
    this.authenticated = authenticated;
    this.guest = guest;
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
      path == '/portfolio' ||
      path == '/resumes' ||
      path == '/resumes/new' ||
      path == '/portfolio/new' ||
      RegExp(r'^/(resumes|portfolio)/[^/]+/edit$').hasMatch(path) ||
      path == '/projects' ||
      path == '/settings' ||
      path == '/settings/appearance' ||
      path == '/settings/account' ||
      path == '/settings/profile' ||
      path == '/settings/contacts' ||
      path == '/settings/contacts/links' ||
      RegExp(
        r'^/settings/profile/(identity|skills|experience|education|links)$',
      ).hasMatch(path) ||
      path == '/portfolio-draft' ||
      path == '/portfolio/preview' ||
      path == '/github-import' ||
      path == '/projects/new' ||
      RegExp(r'^/projects/[^/]+/edit$').hasMatch(path) ||
      RegExp(
        r'^/portfolio/builder(?:/(profile|skills|experience|education|links|resume))?$',
      ).hasMatch(path)) {
    return uri.toString();
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
    if (access?.configured != true) return null;
    if (authForm || path == '/github-import') {
      if (authForm && access!.authenticated && !access.restoring) {
        return safeAuthDestination(state.uri.queryParameters['from']);
      }
      return null;
    }
    if (!access!.canEdit) {
      return Uri(
        path: '/sign-in',
        queryParameters: {'from': state.uri.toString()},
      ).toString();
    }
    return null;
  },
  routes: [
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
      name: 'settings',
      path: '/settings',
      builder: (_, _) => const SettingsScreen(),
      routes: [
        GoRoute(
          name: 'developerProfile',
          path: 'profile',
          builder: (_, _) => const DeveloperProfileScreen(),
          routes: [
            GoRoute(
              name: 'developerIdentity',
              path: 'identity',
              builder: (_, _) => const PortfolioProfileEditorScreen(),
            ),
            GoRoute(
              name: 'developerSkills',
              path: 'skills',
              builder: (_, _) => const PortfolioSkillsEditorScreen(),
            ),
            GoRoute(
              name: 'developerExperience',
              path: 'experience',
              builder: (_, _) => const PortfolioExperienceEditorScreen(),
            ),
            GoRoute(
              name: 'developerEducation',
              path: 'education',
              builder: (_, _) => const PortfolioEducationEditorScreen(),
            ),
            GoRoute(
              name: 'developerLinks',
              path: 'links',
              builder: (_, _) => const PortfolioLinksEditorScreen(),
            ),
          ],
        ),
        GoRoute(
          name: 'developerContacts',
          path: 'contacts',
          builder: (_, _) => const DeveloperProfileScreen(contactsOnly: true),
          routes: [
            GoRoute(
              name: 'developerContactsLinks',
              path: 'links',
              builder: (_, _) => const PortfolioLinksEditorScreen(),
            ),
          ],
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
      ],
    ),
    GoRoute(
      name: 'portfolioDraft',
      path: '/portfolio-draft',
      builder: (_, _) => const PortfolioDraftScreen(),
    ),
    GoRoute(
      name: 'portfolioBuilder',
      path: '/portfolio/builder',
      builder: (_, _) => const PortfolioBuilderScreen(),
      routes: [
        GoRoute(
          name: 'editProfile',
          path: 'profile',
          builder: (_, _) => const PortfolioProfileEditorScreen(),
        ),
        GoRoute(
          name: 'editSkills',
          path: 'skills',
          builder: (_, _) => const PortfolioSkillsEditorScreen(),
        ),
        GoRoute(
          name: 'editExperience',
          path: 'experience',
          builder: (_, _) => const PortfolioExperienceEditorScreen(),
        ),
        GoRoute(
          name: 'editEducation',
          path: 'education',
          builder: (_, _) => const PortfolioEducationEditorScreen(),
        ),
        GoRoute(
          name: 'editLinks',
          path: 'links',
          builder: (_, _) => const PortfolioLinksEditorScreen(),
        ),
        GoRoute(
          name: 'editResume',
          path: 'resume',
          builder: (_, _) => const PortfolioResumeEditorScreen(),
        ),
      ],
    ),
    GoRoute(
      name: 'portfolioPreview',
      path: '/portfolio/preview',
      builder: (_, _) => const PortfolioPreviewScreen(),
    ),
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
    GoRoute(
      name: 'newResume',
      path: '/resumes/new',
      builder: (_, _) => const PortfolioDocumentEditorScreen(
        kind: PortfolioDocumentKind.resume,
      ),
    ),
    GoRoute(
      name: 'editResumeDocument',
      path: '/resumes/:id/edit',
      builder: (_, state) => PortfolioDocumentEditorScreen(
        kind: PortfolioDocumentKind.resume,
        documentId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      name: 'newPortfolioDocument',
      path: '/portfolio/new',
      builder: (_, _) => const PortfolioDocumentEditorScreen(
        kind: PortfolioDocumentKind.portfolio,
      ),
    ),
    GoRoute(
      name: 'editPortfolioDocument',
      path: '/portfolio/:id/edit',
      builder: (_, state) => PortfolioDocumentEditorScreen(
        kind: PortfolioDocumentKind.portfolio,
        documentId: state.pathParameters['id']!,
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(
        location: state.uri.path,
        child: shell,
        onNavigate: (index) => shell.goBranch(index),
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'home',
              path: '/home',
              builder: (_, _) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'resumes',
              path: '/resumes',
              builder: (_, _) => const PortfolioDocumentLibraryScreen(
                kind: PortfolioDocumentKind.resume,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'projects',
              path: '/projects',
              builder: (_, _) => const ProjectsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'portfolio',
              path: '/portfolio',
              builder: (_, _) => const PortfolioDocumentLibraryScreen(
                kind: PortfolioDocumentKind.portfolio,
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
