import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/state/appearance_controller.dart';
import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import '../../shared/widgets/stackcard_states.dart';
import '../portfolio_draft/portfolio_draft.dart';
import 'account_settings_section.dart';
import 'settings_editor_scaffold.dart';
export 'settings_account_screen.dart';
export 'settings_base_editor_screen.dart';
export 'settings_providers.dart';
export 'settings_editor_scaffold.dart';

class SettingsScreen extends riverpod.ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, riverpod.WidgetRef ref) {
    final draft = ref.watch(portfolioDraftControllerProvider);
    final strings = context.strings;
    return _SettingsPage(
      titleKey: 'nav.settings',
      fallbackPath: '/home',
      children: [
        _SettingsRow(
          key: const Key('settings.group.profile'),
          icon: Icons.person_outline_rounded,
          title: strings.tr('workspace.profile'),
          onPressed: () => context.push('/settings/profile'),
        ),
        _SettingsRow(
          key: const Key('settings.group.contacts'),
          icon: Icons.link_rounded,
          title: strings.tr('settings.contacts'),
          onPressed: () => context.push('/settings/contacts'),
        ),
        if (!draft.loaded && draft.failure != null) ...[
          const SizedBox(height: StackCardSpacing.md),
          StackCardStateView(
            kind: StackCardViewState.error,
            title: strings.tr('async.errorTitle'),
            message: strings.tr('async.errorMessage'),
            onRetry: () =>
                ref.read(portfolioDraftControllerProvider.notifier).load(),
          ),
        ],
        _SettingsRow(
          key: const Key('settings.group.account'),
          icon: Icons.shield_outlined,
          title: strings.tr('settings.accountSecurity'),
          onPressed: () => context.push('/settings/account'),
        ),
        _SettingsRow(
          key: const Key('settings.group.privacy'),
          icon: Icons.lock_outline_rounded,
          title: strings.tr('settings.privacy'),
          onPressed: () => context.push('/settings/privacy'),
        ),
        _SettingsRow(
          key: const Key('settings.group.appearance'),
          icon: Icons.tune_rounded,
          title: strings.tr('settings.application'),
          onPressed: () => context.push('/settings/appearance'),
        ),
        _SettingsRow(
          key: const Key('settings.group.inbox'),
          icon: Icons.inbox_outlined,
          title: strings.tr('inbox.title'),
          onPressed: () => context.push('/inbox'),
        ),
        _SettingsRow(
          key: const Key('settings.group.notifications'),
          icon: Icons.notifications_none_rounded,
          title: strings.tr('settings.notifications'),
          onPressed: () => context.push('/settings/notifications'),
          showDivider: false,
        ),
        Divider(
          height: StackCardSpacing.lg,
          thickness: 1,
          color: context.colors.borderStrong,
        ),
        const AccountSettingsSection(),
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
        SwitchListTile.adaptive(
          key: const Key('settings.sourceDescriptions'),
          contentPadding: EdgeInsets.zero,
          title: Text(strings.tr('settings.sourceDescriptions')),
          value: appearance.showSourceDescriptions,
          onChanged: appearance.setShowSourceDescriptions,
        ),
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
          onPressed: () => context.push('/settings/notifications'),
        ),
        SwitchListTile.adaptive(
          key: const Key('settings.reducedMotion'),
          contentPadding: EdgeInsets.zero,
          title: Text(strings.tr('settings.reducedMotion')),
          subtitle: MediaQuery.disableAnimationsOf(context)
              ? Text(strings.tr('settingsManagement.systemMotion'))
              : null,
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
  Widget build(BuildContext context) => SettingsEditorScaffold(
    title: context.strings.tr(titleKey),
    onBack: () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(fallbackPath);
      }
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.onPressed,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onPressed;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colors.border))
            : null,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.md),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 24, color: colors.textSecondary),
              ),
              const SizedBox(width: StackCardSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onPressed != null) ...[
                const SizedBox(width: StackCardSpacing.sm),
                const ExcludeSemantics(
                  child: Icon(Icons.chevron_right_rounded, size: 20),
                ),
              ],
            ],
          ),
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
