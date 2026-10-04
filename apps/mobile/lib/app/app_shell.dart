import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/stackcard_colors.dart';
import '../core/localization/app_strings.dart';
import '../shared/widgets/stackcard_brand.dart';
import '../features/portfolio_draft/portfolio_draft.dart';
import '../features/profile/profile.dart';

const _destinations = [
  (path: '/home', label: 'nav.home', icon: Icons.space_dashboard_outlined),
  (path: '/portfolio', label: 'nav.portfolio', icon: Icons.badge_outlined),
  (path: '/projects', label: 'nav.projects', icon: Icons.layers_outlined),
  (path: '/settings', label: 'nav.settings', icon: Icons.tune_rounded),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(portfolioDraftControllerProvider);
    final profile = ref.watch(profileProvider);
    final initials = !profile.isLoading && !profile.hasError
        ? profile.value?.initials ?? '?'
        : '?';
    final selected = _destinations.indexWhere((item) => item.path == location);
    final index = selected < 0 ? 0 : selected;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    void navigate(int index) {
      if (_destinations[index].path != location) {
        context.push(_destinations[index].path);
      }
    }

    return Scaffold(
      body: SafeArea(
        bottom: wide,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                child: Container(
                  width: 80,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.colors.borderSubtle),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: StackCardBrand(compact: true),
                        ),
                        for (var i = 0; i < _destinations.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: IconButton(
                              tooltip: context.strings.tr(
                                _destinations[i].label,
                              ),
                              isSelected: index == i,
                              onPressed: () => navigate(i),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                foregroundColor: index == i
                                    ? context.colors.accent
                                    : context.colors.textSecondary,
                                backgroundColor: index == i
                                    ? context.colors.accentSoft
                                    : context.colors.surface,
                              ),
                              icon: Icon(_destinations[i].icon),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircleAvatar(child: Text(initials)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                draft.content != null
                                    ? context.strings.tr(
                                        'builderIntegration.shellDraft',
                                      )
                                    : draft.loaded
                                    ? 'STACKCARD / DEMO'
                                    : 'STACKCARD',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.strings.tr(_destinations[index].label),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                            ],
                          ),
                        ),
                        if (location != '/home' || context.canPop())
                          IconButton(
                            tooltip: context.strings.tr('common.back'),
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/home');
                              }
                            },
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        IconButton(
                          tooltip: context.strings.tr('nav.signIn'),
                          onPressed: () => context.go('/sign-in'),
                          icon: const Icon(Icons.logout_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: navigate,
              labelBehavior: largeText
                  ? NavigationDestinationLabelBehavior.alwaysHide
                  : NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    label: context.strings.tr(item.label),
                    tooltip: context.strings.tr(item.label),
                  ),
              ],
            ),
    );
  }
}
