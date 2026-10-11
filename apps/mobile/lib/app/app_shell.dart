import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_strings.dart';
import '../core/theme/stackcard_colors.dart';
import '../core/theme/stackcard_tokens.dart';
import '../shared/widgets/stackcard_brand.dart';
import '../shared/widgets/stackcard_icon.dart';
import '../features/portfolio_draft/portfolio_draft.dart';

// Три раздела сохраняют состояние при переключении вкладок.
const _destinations = [
  (path: '/home', label: 'nav.home', icon: 'home'),
  (path: '/projects', label: 'nav.projects', icon: 'folder'),
  (path: '/editor', label: 'nav.editor', icon: 'file-text'),
];

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.location,
    required this.child,
    this.onNavigate,
  });
  final String location;
  final Widget child;
  final void Function(int)? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = _destinations.indexWhere((item) => item.path == location);
    final index = selected < 0 ? 0 : selected;
    final compactHeader = MediaQuery.sizeOf(context).height < 400;
    Future<void> navigate(int destination) async {
      if (_destinations[destination].path == location) return;
      final guard = ref.read(mainPortfolioEditorNavigationProvider);
      if (location == '/editor' && guard != null && !await guard()) return;
      if (!context.mounted) return;
      if (_destinations[destination].path != location) {
        if (onNavigate != null) {
          onNavigate!(destination);
        } else {
          context.go(_destinations[destination].path);
        }
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
                  padding: const EdgeInsets.fromLTRB(
                    StackCardSpacing.lg,
                    StackCardSpacing.md,
                    StackCardSpacing.lg,
                    StackCardSpacing.sm,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      border: Border.all(color: context.colors.border),
                      borderRadius: BorderRadius.circular(
                        StackCardRadius.capsule,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: StackCardSpacing.lg,
                        right: StackCardSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          if (compactHeader && index != 0) ...[
                            const StackCardBrand(compact: true),
                            const SizedBox(width: StackCardSpacing.sm),
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  context.strings.tr(
                                    _destinations[index].label,
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                            ),
                          ] else
                            const Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: 172,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: StackCardBrand(),
                                  ),
                                ),
                              ),
                            ),
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
                            onPressed: () async {
                              final guard = ref.read(
                                mainPortfolioEditorNavigationProvider,
                              );
                              if (location == '/editor' &&
                                  guard != null &&
                                  !await guard()) {
                                return;
                              }
                              if (context.mounted) context.push('/settings');
                            },
                            icon: const StackCardIcon(name: 'settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (index != 0 && !compactHeader)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      StackCardSpacing.lg,
                      StackCardSpacing.xl,
                      StackCardSpacing.lg,
                      StackCardSpacing.xs,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        context.strings.tr(_destinations[index].label),
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
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
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                StackCardSpacing.md,
                StackCardSpacing.sm,
                StackCardSpacing.md,
                StackCardSpacing.md,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border.all(color: context.colors.border),
                  borderRadius: BorderRadius.circular(StackCardRadius.xlarge),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.ink.withValues(alpha: .05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(StackCardRadius.xlarge),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final textTheme = Theme.of(context).textTheme;
                      final textStyle = constraints.maxWidth < 360
                          ? textTheme.labelSmall
                          : textTheme.labelMedium;
                      final textScaler = MediaQuery.textScalerOf(context);
                      var labelHeight = 0.0;
                      for (final item in _destinations) {
                        final painter =
                            TextPainter(
                              text: TextSpan(
                                text: context.strings.tr(item.label),
                                style: textStyle?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              textScaler: textScaler,
                              textDirection: Directionality.of(context),
                            )..layout(
                              maxWidth: math.max(
                                0.0,
                                constraints.maxWidth / _destinations.length -
                                    StackCardSpacing.xs,
                              ),
                            );
                        labelHeight = math.max(labelHeight, painter.height);
                        painter.dispose();
                      }
                      return NavigationBar(
                        height: math.max(72.0, labelHeight + 56),
                        selectedIndex: index,
                        onDestinationSelected: navigate,
                        animationDuration:
                            MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : StackCardMotion.fast,
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysShow,
                        destinations: [
                          for (var i = 0; i < _destinations.length; i++)
                            _RootDestination(
                              label: context.strings.tr(_destinations[i].label),
                              icon: _destinations[i].icon,
                              selected: i == index,
                              labelStyle: textStyle,
                              onPressed: () => navigate(i),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
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
    required this.labelStyle,
    required this.onPressed,
  });

  final String label;
  final String icon;
  final bool selected;
  final TextStyle? labelStyle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(StackCardSpacing.xs / 2),
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
                horizontal: 0,
                vertical: StackCardSpacing.sm,
              ),
              foregroundColor: selected
                  ? context.colors.onPrimary
                  : context.colors.textSecondary,
              backgroundColor: selected
                  ? context.colors.primary
                  : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(StackCardRadius.medium),
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.focused)
                      ? selected
                            ? context.colors.onPrimary
                            : context.colors.focus
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: StackCardIcon(
                name: icon,
                size: 24,
                color: selected
                    ? context.colors.onPrimary
                    : context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: StackCardSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: labelStyle?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? context.colors.onPrimary
                    : context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
