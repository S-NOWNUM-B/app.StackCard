import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_icon.dart';

/// Общая шапка и неподвижная панель настроек; содержимое прокручивается отдельно.
class SettingsEditorScaffold extends StatelessWidget {
  const SettingsEditorScaffold({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.onBack,
  });
  final String title;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onBack;
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
                padding: const EdgeInsets.symmetric(
                  horizontal: StackCardSpacing.cardPadding,
                  vertical: StackCardSpacing.md,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: context.strings.tr('common.back'),
                      onPressed:
                          onBack ??
                          () => context.canPop()
                              ? context.pop()
                              : context.go('/settings'),
                      icon: const StackCardIcon(name: 'arrow-left'),
                    ),
                    const SizedBox(width: StackCardSpacing.md),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
                  child: child,
                ),
              ),
              if (footer != null)
                ColoredBox(
                  color: context.colors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
                    child: footer!,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SettingsSaveBar extends StatelessWidget {
  const SettingsSaveBar({
    super.key,
    required this.status,
    required this.onCancel,
    required this.onSave,
    this.saving = false,
  });
  final String status;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;
  final bool saving;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        liveRegion: true,
        child: Text(
          status,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.colors.textSecondary),
        ),
      ),
      const SizedBox(height: StackCardSpacing.sm),
      Row(
        children: [
          Expanded(
            child: StackCardButton(
              label: context.strings.tr('account.cancel'),
              role: StackCardButtonRole.secondary,
              onPressed: onCancel,
            ),
          ),
          const SizedBox(width: StackCardSpacing.sm),
          Expanded(
            child: StackCardButton(
              key: const Key('settings.save'),
              label: context.strings.tr('settingsManagement.save'),
              loading: saving,
              onPressed: onSave,
            ),
          ),
        ],
      ),
    ],
  );
}
