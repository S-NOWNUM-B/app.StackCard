import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_strings.dart';
import '../core/theme/stackcard_colors.dart';
import '../core/theme/stackcard_tokens.dart';

// Только существующие root routes: Resume ждёт отдельного data contract.
const _destinations = [
  (path: '/home', label: 'nav.home', icon: Icons.space_dashboard_outlined),
  (path: '/portfolio', label: 'nav.portfolio', icon: Icons.badge_outlined),
  (path: '/projects', label: 'nav.projects', icon: Icons.layers_outlined),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selected = _destinations.indexWhere((item) => item.path == location);
    final index = selected < 0 ? 0 : selected;
    void navigate(int destination) {
      if (_destinations[destination].path != location) {
        context.push(_destinations[destination].path);
      }
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: StackCardSize.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StackCardSpacing.lg,
                    vertical: StackCardSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      if (location != '/home' || context.canPop())
                        IconButton(
                          tooltip: context.strings.tr('common.back'),
                          constraints: const BoxConstraints(
                            minWidth: StackCardSize.touchTarget,
                            minHeight: StackCardSize.touchTarget,
                          ),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/home');
                            }
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      const Spacer(),
                      IconButton(
                        key: const Key('app.settings'),
                        style: ButtonStyle(
                          side: WidgetStateProperty.resolveWith(
                            (states) => BorderSide(
                              color: states.contains(WidgetState.focused)
                                  ? context.colors.focus
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        tooltip: context.strings.tr('nav.settings'),
                        constraints: const BoxConstraints(
                          minWidth: StackCardSize.touchTarget,
                          minHeight: StackCardSize.touchTarget,
                        ),
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: StackCardSize.contentMaxWidth,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textStyle = Theme.of(context).textTheme.labelMedium;
              final textScaler = MediaQuery.textScalerOf(context);
              var labelHeight = 0.0;
              for (final item in _destinations) {
                final painter =
                    TextPainter(
                      text: TextSpan(
                        text: context.strings.tr(item.label),
                        style: textStyle?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      textScaler: textScaler,
                      textDirection: Directionality.of(context),
                    )..layout(
                      maxWidth:
                          constraints.maxWidth / _destinations.length -
                          StackCardSpacing.lg,
                    );
                labelHeight = math.max(labelHeight, painter.height);
                painter.dispose();
              }
              return NavigationBar(
                height: math.max(72.0, labelHeight + 56),
                selectedIndex: index,
                onDestinationSelected: navigate,
                animationDuration: StackCardMotion.fast,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  for (var i = 0; i < _destinations.length; i++)
                    _RootDestination(
                      label: context.strings.tr(_destinations[i].label),
                      icon: _destinations[i].icon,
                      selected: i == index,
                      onPressed: () => navigate(i),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// Стандартный NavigationDestination ограничивает text scale до 1.3.
// Здесь labels используют полный OS scaling и растущую высоту нижней панели.
class _RootDestination extends StatelessWidget {
  const _RootDestination({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(StackCardSpacing.xs),
    child: Semantics(
      selected: selected,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              minimumSize: const Size(
                StackCardSize.touchTarget,
                StackCardSize.touchTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: StackCardSpacing.xs,
                vertical: StackCardSpacing.sm,
              ),
              foregroundColor: selected
                  ? context.colors.accentText
                  : context.colors.textSecondary,
              backgroundColor: selected
                  ? context.colors.accentSoft
                  : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(StackCardRadius.medium),
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.focused)
                      ? context.colors.focus
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 24)),
            const SizedBox(height: StackCardSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? context.colors.accentText
                    : context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
