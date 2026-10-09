import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/state/app_settings.dart';
import '../../core/state/appearance_controller.dart';
import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import '../../shared/widgets/stackcard_async_view.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_card.dart';
import '../../shared/widgets/stackcard_states.dart';
import '../auth/auth.dart';
import '../portfolio_draft/portfolio_draft.dart';
import '../profile/profile.dart';
import 'account_settings_section.dart';
export 'settings_account_screen.dart';
export 'settings_base_editor_screen.dart';
export 'settings_providers.dart';
export 'settings_editor_scaffold.dart';

class SettingsScreen extends riverpod.ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, riverpod.WidgetRef ref) {
    final draft = ref.watch(portfolioDraftControllerProvider);
    final hasAccountRepository =
        ref.watch(accountAuthRepositoryProvider) != null;
    final strings = context.strings;
    return _SettingsPage(
      titleKey: 'nav.settings',
      fallbackPath: '/home',
      children: [
        _SettingsRow(
          key: const Key('settings.group.profile'),
          icon: Icons.person_outline_rounded,
          title: strings.tr('workspace.profile'),
          subtitle: strings.tr('workspace.profileHint'),
          onPressed: () => context.push('/settings/profile'),
        ),
        _SettingsRow(
          key: const Key('settings.group.contacts'),
          icon: Icons.link_rounded,
          title: strings.tr('settings.contacts'),
          subtitle: strings.tr('workspace.contactsHint'),
          onPressed: () => context.push('/settings/contacts'),
        ),
        // В demo режиме ошибка draft уже показана profile AsyncView ниже.
        if (hasAccountRepository && !draft.loaded && draft.failure != null) ...[
          const SizedBox(height: StackCardSpacing.md),
          StackCardStateView(
            kind: StackCardViewState.error,
            title: strings.tr('async.errorTitle'),
            message: strings.tr('async.errorMessage'),
            onRetry: () =>
                ref.read(portfolioDraftControllerProvider.notifier).load(),
          ),
        ],
        const SizedBox(height: StackCardSpacing.lg),
        _SettingsRow(
          key: const Key('settings.group.account'),
          icon: Icons.shield_outlined,
          title: strings.tr('settings.accountSecurity'),
          subtitle: strings.tr('settings.accountSecurityNote'),
          onPressed: () => context.push('/settings/account'),
        ),
        _SettingsRow(
          key: const Key('settings.group.privacy'),
          icon: Icons.lock_outline_rounded,
          title: strings.tr('settings.privacy'),
          subtitle: strings.tr('settingsManagement.privacyHint'),
          onPressed: () => context.push('/settings/privacy'),
        ),
        _SettingsRow(
          key: const Key('settings.group.appearance'),
          icon: Icons.tune_rounded,
          title: strings.tr('settings.application'),
          subtitle: strings.tr('settings.applicationNote'),
          onPressed: () => context.push('/settings/appearance'),
        ),
        _SettingsRow(
          key: const Key('settings.group.inbox'),
          icon: Icons.inbox_outlined,
          title: strings.tr('inbox.title'),
          subtitle: strings.tr('inbox.hint'),
          onPressed: () => context.push('/inbox'),
        ),
        _SettingsRow(
          key: const Key('settings.group.notifications'),
          icon: Icons.notifications_none_rounded,
          title: strings.tr('settings.notifications'),
          subtitle: strings.tr('notifications.hint'),
          onPressed: () => context.push('/settings/notifications'),
        ),
        const SizedBox(height: StackCardSpacing.xl),
        _SettingsHeading(title: strings.tr('settings.session')),
        const SizedBox(height: StackCardSpacing.md),
        if (hasAccountRepository)
          const AccountSettingsSection()
        else
          const _DemoAccountSection(),
        const SizedBox(height: StackCardSpacing.xl),
        StackCardButton(
          key: const Key('settings.deleteAccount'),
          label: strings.tr('settings.deleteAccount'),
          role: StackCardButtonRole.danger,
          onPressed: () => context.push('/settings/account'),
        ),
      ],
    );
  }
}

/// Route /settings/appearance: сохраняет только существующий AppSettings.
class SettingsAppearanceScreen extends StatelessWidget {
  const SettingsAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceController>();
    final strings = context.strings;
    return _SettingsPage(
      titleKey: 'settings.application',
      children: [
        _SettingsHeading(title: strings.tr('settings.appearance')),
        const SizedBox(height: StackCardSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final horizontal =
                constraints.maxWidth >= 340 &&
                MediaQuery.textScalerOf(context).scale(16) <= 20;
            return Wrap(
              spacing: StackCardSpacing.sm,
              runSpacing: StackCardSpacing.sm,
              children: [
                for (final item in [
                  (
                    mode: ThemeMode.dark,
                    title: strings.tr('settings.dark'),
                    icon: Icons.dark_mode_outlined,
                  ),
                  (
                    mode: ThemeMode.light,
                    title: strings.tr('settings.light'),
                    icon: Icons.light_mode_outlined,
                  ),
                  (
                    mode: ThemeMode.system,
                    title: strings.tr('settings.system'),
                    icon: Icons.brightness_auto_outlined,
                  ),
                ])
                  SizedBox(
                    width: horizontal
                        ? (constraints.maxWidth - StackCardSpacing.sm * 2) / 3
                        : constraints.maxWidth,
                    child: _SettingsChoice(
                      key: Key('settings.theme.${item.mode.name}'),
                      label: item.title,
                      icon: item.icon,
                      selected: appearance.themeMode == item.mode,
                      onPressed: () => appearance.setThemeMode(item.mode),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: StackCardSpacing.xl),
        _SettingsHeading(title: strings.tr('settings.language')),
        const SizedBox(height: StackCardSpacing.md),
        Wrap(
          spacing: StackCardSpacing.md,
          runSpacing: StackCardSpacing.sm,
          children: [
            for (final item in [
              (language: AppLanguage.ru, label: 'Русский'),
              (language: AppLanguage.en, label: 'English'),
            ])
              _SettingsChoice(
                key: Key('settings.language.${item.language.name}'),
                label: item.label,
                selected: appearance.settings.language == item.language,
                onPressed: () => appearance.setLanguage(item.language),
              ),
          ],
        ),
        const SizedBox(height: StackCardSpacing.sm),
        _SettingsNote(text: strings.tr('settings.languageNote')),
        const SizedBox(height: StackCardSpacing.xl),
        SwitchListTile.adaptive(
          key: const Key('settings.sourceDescriptions'),
          contentPadding: EdgeInsets.zero,
          title: Text(strings.tr('settings.sourceDescriptions')),
          subtitle: Text(strings.tr('settings.sourceDescriptionsNote')),
          value: appearance.showSourceDescriptions,
          onChanged: appearance.setShowSourceDescriptions,
        ),
        const SizedBox(height: StackCardSpacing.lg),
        _SettingsNote(text: strings.tr('settings.localPreferencesNote')),
        if (appearance.isSaving) ...[
          const SizedBox(height: StackCardSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(strings.tr('settings.saving')),
          ),
        ],
        if (appearance.saveFailure != null) ...[
          const SizedBox(height: StackCardSpacing.md),
          StackCardStateView(
            kind: StackCardViewState.error,
            title: strings.tr('settings.saveError'),
            message: strings.tr('settings.saveErrorNote'),
            onRetry: appearance.retrySave,
          ),
        ],
        const SizedBox(height: StackCardSpacing.xl),
        _SettingsRow(
          icon: Icons.notifications_none_rounded,
          title: strings.tr('settings.notifications'),
          subtitle: strings.tr('notifications.hint'),
          onPressed: () => context.push('/settings/notifications'),
        ),
        SwitchListTile.adaptive(
          key: const Key('settings.reducedMotion'),
          contentPadding: EdgeInsets.zero,
          title: Text(strings.tr('settings.reducedMotion')),
          subtitle: Text(
            strings.tr(
              MediaQuery.disableAnimationsOf(context)
                  ? 'settingsManagement.systemMotion'
                  : 'settingsManagement.reducedHint',
            ),
          ),
          value: appearance.reducedMotion,
          onChanged: appearance.setReducedMotion,
        ),
      ],
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.titleKey,
    required this.children,
    this.fallbackPath = '/settings',
  });

  final String titleKey;
  final List<Widget> children;
  final String fallbackPath;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: StackCardSize.contentMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(StackCardSpacing.sm),
                child: Row(
                  children: [
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
                          context.go(fallbackPath);
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: StackCardSpacing.sm),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          context.strings.tr(titleKey),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    StackCardSpacing.cardPadding,
                    StackCardSpacing.md,
                    StackCardSpacing.cardPadding,
                    StackCardSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.lg),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 24, color: colors.textSecondary),
            ),
            const SizedBox(width: StackCardSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: StackCardSpacing.xs),
                  _SettingsNote(text: subtitle),
                ],
              ),
            ),
            if (onPressed != null) ...[
              const SizedBox(width: StackCardSpacing.sm),
              const ExcludeSemantics(child: Icon(Icons.chevron_right_rounded)),
            ],
          ],
        ),
      ),
    );
    if (onPressed == null) return content;
    return TextButton(
      onPressed: onPressed,
      style:
          TextButton.styleFrom(
            minimumSize: const Size.fromHeight(StackCardSize.touchTarget),
            padding: EdgeInsets.zero,
            foregroundColor: colors.textPrimary,
            alignment: Alignment.centerLeft,
            shape: const RoundedRectangleBorder(),
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.focused)
                    ? colors.focus
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
      child: content,
    );
  }
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _SettingsNote extends StatelessWidget {
  const _SettingsNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: context.colors.textSecondary),
  );
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
            color: selected
                ? context.colors.controlOutline
                : context.colors.border,
            width: selected ? 2 : 1,
          ),
        ),
      ),
      child: TextButton(
        style:
            TextButton.styleFrom(
              foregroundColor: context.colors.textPrimary,
              minimumSize: const Size(
                StackCardSize.touchTarget,
                StackCardSize.touchTarget,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              shape: const RoundedRectangleBorder(),
              backgroundColor: selected
                  ? context.colors.surfaceElevated
                  : Colors.transparent,
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
