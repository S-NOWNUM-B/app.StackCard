import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../../settings/settings_screen.dart';
import '../notifications_providers.dart';
import '../domain/push_notifications.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(notificationsControllerProvider);
    final snapshot = ref.watch(notificationStateProvider);
    final state =
        snapshot.value ?? controller?.state ?? const PushNotificationState();
    final strings = context.strings;
    return SettingsEditorScaffold(
      title: strings.tr('settings.notifications'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.tr('notifications.hint')),
          const SizedBox(height: StackCardSpacing.lg),
          Semantics(
            liveRegion: true,
            child: Text(
              strings.tr('notifications.permission.${state.permission.name}'),
            ),
          ),
          Text(
            strings.tr(
              state.enabled
                  ? 'notifications.enabled'
                  : 'notifications.disabled',
            ),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          if (controller == null)
            StackCardStateView(
              kind: StackCardViewState.unavailable,
              title: strings.tr('notifications.unavailable'),
              message: strings.tr('notifications.inboxWorks'),
            )
          else ...[
            StackCardButton(
              key: const Key('notifications.enable'),
              label: strings.tr('notifications.enable'),
              loading: state.busy,
              onPressed: state.busy || state.enabled ? null : controller.enable,
            ),
            const SizedBox(height: StackCardSpacing.md),
            StackCardButton(
              key: const Key('notifications.disable'),
              label: strings.tr('notifications.disable'),
              role: StackCardButtonRole.secondary,
              onPressed: state.busy ? null : controller.disable,
            ),
          ],
          if (state.failure != null)
            Padding(
              padding: const EdgeInsets.only(top: StackCardSpacing.lg),
              child: StackCardStateView(
                kind: StackCardViewState.error,
                title: strings.tr('notifications.error'),
                message: strings.tr(
                  'notifications.error.${state.failure!.name}',
                ),
              ),
            ),
          const SizedBox(height: StackCardSpacing.lg),
          Text(strings.tr('notifications.inboxWorks')),
          const SizedBox(height: StackCardSpacing.md),
          StackCardButton(
            label: strings.tr('inbox.title'),
            role: StackCardButtonRole.secondary,
            onPressed: () => context.push('/inbox'),
          ),
        ],
      ),
    );
  }
}
