import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/state/app_settings.dart';
import '../../core/state/appearance_controller.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_card.dart';
import '../../shared/widgets/stackcard_states.dart';
import '../../shared/widgets/stackcard_async_view.dart';
import '../profile/profile.dart';
import '../portfolio_draft/portfolio_draft.dart';

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
              StackCardCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.strings.tr('settings.appearance'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.strings.tr('settings.appearanceNote'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                          ChoiceChip(
                            avatar: Icon(item.icon, size: 18),
                            label: Text(item.title),
                            selected: themeMode == item.mode,
                            onSelected: (_) {
                              context.read<AppearanceController>().setThemeMode(
                                item.mode,
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _PreferencesCard(),
              const SizedBox(height: 16),
              StackCardCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    riverpod.Consumer(
                      builder: (context, ref, _) => Text(
                        context.strings.tr(
                          ref.watch(portfolioWorkingContentProvider) == null
                              ? 'settings.demoAccount'
                              : 'builderIntegration.localProfile',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    riverpod.Consumer(
                      builder: (context, ref, _) => StackCardAsyncView(
                        state: ref.watch(profileProvider),
                        onRetry: () {
                          ref
                              .read(portfolioDraftControllerProvider.notifier)
                              .load();
                          ref.invalidate(profileProvider);
                        },
                        data: (profile) => Text(
                          profile.name.isEmpty
                              ? context.strings.tr(
                                  'builderIntegration.emptyProfile',
                                )
                              : [profile.name, profile.handle]
                                    .where((value) => value.isNotEmpty)
                                    .join(' · '),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    riverpod.Consumer(
                      builder: (context, ref, _) => Text(
                        context.strings.tr(
                          ref.watch(portfolioWorkingContentProvider) == null
                              ? 'settings.demoNote'
                              : 'builderIntegration.localNote',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: context.colors.textSecondary),
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
              ),
              const SizedBox(height: 16),
              StackCardCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.strings.tr('settings.states'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.strings.tr('settings.statesNote'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard();

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceController>();
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.strings.tr('settings.language'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(context.strings.tr('settings.languageNote')),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in [
                (language: AppLanguage.ru, label: 'Русский'),
                (language: AppLanguage.en, label: 'English'),
              ])
                ChoiceChip(
                  label: Text(item.label),
                  selected: appearance.settings.language == item.language,
                  onSelected: (_) => appearance.setLanguage(item.language),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(context.strings.tr('settings.sourceDescriptions')),
              subtitle: Text(
                context.strings.tr('settings.sourceDescriptionsNote'),
              ),
              value: appearance.showSourceDescriptions,
              onChanged: appearance.setShowSourceDescriptions,
            ),
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
