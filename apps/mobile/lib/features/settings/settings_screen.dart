import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/state/app_settings.dart';
import '../../core/state/appearance_controller.dart';
import '../../core/theme/stackcard_colors.dart';
import '../../shared/widgets/stackcard_async_view.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_card.dart';
import '../../shared/widgets/stackcard_poster.dart';
import '../../shared/widgets/stackcard_states.dart';
import '../auth/auth.dart';
import '../portfolio_draft/portfolio_draft.dart';
import '../profile/profile.dart';
import 'account_settings_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StackCardViewState _previewState = StackCardViewState.empty;

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppearanceController, ThemeMode>(
      (controller) => controller.themeMode,
    );
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        MediaQuery.sizeOf(context).width >= 700 ? 24 : 16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StackCardPoster(
                color: context.colors.acid,
                variant: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.strings.tr('settings.appearance'),
                      style: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(color: context.colors.ink),
                    ),
                    StackCardArtwork(
                      color: context.colors.ink,
                      variant: 1,
                      height: 100,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal =
                      constraints.maxWidth >= 340 &&
                      MediaQuery.textScalerOf(context).scale(16) <= 24;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final item in [
                        (
                          mode: ThemeMode.dark,
                          title: context.strings.tr('settings.dark'),
                          icon: Icons.dark_mode_outlined,
                        ),
                        (
                          mode: ThemeMode.light,
                          title: context.strings.tr('settings.light'),
                          icon: Icons.light_mode_outlined,
                        ),
                        (
                          mode: ThemeMode.system,
                          title: context.strings.tr('settings.system'),
                          icon: Icons.brightness_auto_outlined,
                        ),
                      ])
                        SizedBox(
                          width: horizontal
                              ? (constraints.maxWidth - 16) / 3
                              : constraints.maxWidth,
                          child: _SettingsChoice(
                            key: Key('settings.theme.${item.mode.name}'),
                            label: item.title,
                            icon: item.icon,
                            selected: themeMode == item.mode,
                            onPressed: () => context
                                .read<AppearanceController>()
                                .setThemeMode(item.mode),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              const _PreferencesSection(),
              const SizedBox(height: 24),
              riverpod.Consumer(
                builder: (context, ref, _) =>
                    ref.watch(accountAuthRepositoryProvider) != null
                    ? const AccountSettingsSection()
                    : const _DemoAccountSection(),
              ),
              const SizedBox(height: 24),
              ExpansionTile(
                key: const Key('settings_state_previews'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 16),
                title: Text(
                  context.strings.tr('settings.states'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in [
                        (
                          state: StackCardViewState.loading,
                          label: context.strings.tr('common.loading'),
                        ),
                        (
                          state: StackCardViewState.empty,
                          label: context.strings.tr('settings.empty'),
                        ),
                        (
                          state: StackCardViewState.error,
                          label: context.strings.tr('settings.error'),
                        ),
                      ])
                        ChoiceChip(
                          label: Text(item.label),
                          selected: _previewState == item.state,
                          onSelected: (_) =>
                              setState(() => _previewState = item.state),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  StackCardStateView(
                    kind: _previewState,
                    title: switch (_previewState) {
                      StackCardViewState.loading => context.strings.tr(
                        'settings.loadingTitle',
                      ),
                      StackCardViewState.empty => context.strings.tr(
                        'settings.emptyTitle',
                      ),
                      StackCardViewState.error => context.strings.tr(
                        'settings.errorTitle',
                      ),
                    },
                    message: switch (_previewState) {
                      StackCardViewState.loading => context.strings.tr(
                        'settings.loadingMessage',
                      ),
                      StackCardViewState.empty => context.strings.tr(
                        'settings.emptyMessage',
                      ),
                      StackCardViewState.error => context.strings.tr(
                        'settings.errorMessage',
                      ),
                    },
                    onRetry: _previewState == StackCardViewState.error
                        ? () => setState(
                            () => _previewState = StackCardViewState.empty,
                          )
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection();

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceController>();
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.strings.tr('settings.language'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              for (final item in [
                (language: AppLanguage.ru, label: 'Русский'),
                (language: AppLanguage.en, label: 'English'),
              ])
                _SettingsChoice(
                  label: item.label,
                  selected: appearance.settings.language == item.language,
                  onPressed: () => appearance.setLanguage(item.language),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(context.strings.tr('settings.sourceDescriptions')),
            value: appearance.showSourceDescriptions,
            onChanged: appearance.setShowSourceDescriptions,
          ),
          if (appearance.isSaving) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(context.strings.tr('settings.saving')),
            ),
          ],
          if (appearance.saveFailure != null) ...[
            const SizedBox(height: 8),
            StackCardStateView(
              kind: StackCardViewState.error,
              title: context.strings.tr('settings.saveError'),
              message: context.strings.tr('settings.saveErrorNote'),
              onRetry: appearance.retrySave,
            ),
          ],
        ],
      ),
    );
  }
}

class _DemoAccountSection extends riverpod.ConsumerWidget {
  const _DemoAccountSection();

  @override
  Widget build(BuildContext context, riverpod.WidgetRef ref) {
    final isDemo = ref.watch(portfolioWorkingContentProvider) == null;
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.strings.tr(
              isDemo
                  ? 'settings.demoAccount'
                  : 'builderIntegration.localProfile',
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          StackCardAsyncView(
            state: ref.watch(profileProvider),
            onRetry: () {
              ref.read(portfolioDraftControllerProvider.notifier).load();
              ref.invalidate(profileProvider);
            },
            data: (profile) => Text(
              profile.name.isEmpty
                  ? context.strings.tr('builderIntegration.emptyProfile')
                  : [
                      profile.name,
                      profile.handle,
                    ].where((value) => value.isNotEmpty).join(' · '),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 20),
          StackCardButton(
            label: context.strings.tr('settings.signOut'),
            icon: Icons.logout_rounded,
            onPressed: () => context.go('/sign-in'),
          ),
        ],
      ),
    );
  }
}

class _SettingsChoice extends StatelessWidget {
  const _SettingsChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? context.colors.accent : context.colors.border,
            width: selected ? 2 : 1,
          ),
        ),
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: context.colors.textPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          shape: const RoundedRectangleBorder(),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
