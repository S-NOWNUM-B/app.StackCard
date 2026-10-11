import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../auth_providers.dart';
import 'auth_controller.dart';
import 'account_auth_form.dart';

class AccountCard extends ConsumerStatefulWidget {
  const AccountCard({super.key, this.beforeSignOut});

  final Future<bool> Function()? beforeSignOut;

  @override
  ConsumerState<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<AccountCard> {
  bool _confirming = false;

  Future<void> _signOut() async {
    if (_confirming || ref.read(accountAuthControllerProvider).isLoading) {
      return;
    }
    setState(() => _confirming = true);
    try {
      final allowed = await widget.beforeSignOut?.call() ?? true;
      if (!mounted || !allowed) return;
      final success = await ref
          .read(accountAuthControllerProvider.notifier)
          .signOut();
      if (mounted && success) context.go('/sign-in');
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(accountSessionProvider);
    final operation = ref.watch(accountAuthControllerProvider);
    final user = session.value;
    final errorKey = accountAuthErrorKey(operation.error);
    final busy = operation.isLoading || _confirming;
    final strings = context.strings;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(16) > 20;
        final ready = !session.isLoading && !session.hasError;
        final title = session.isLoading
            ? strings.tr('account.sessionRestoring')
            : session.hasError
            ? strings.tr('account.sessionError')
            : user == null
            ? strings.tr('account.title')
            : [user.displayName, user.email]
                      .whereType<String>()
                      .map((value) => value.trim())
                      .where((value) => value.isNotEmpty)
                      .firstOrNull ??
                  strings.tr('account.title');
        final actionLabel = strings.tr(
          session.hasError
              ? 'common.retry'
              : user == null
              ? 'account.signIn'
              : 'account.signOut',
        );
        final actionIcon = session.hasError
            ? Icons.refresh_rounded
            : user == null
            ? Icons.login_rounded
            : Icons.logout_rounded;
        final VoidCallback? action = session.isLoading || busy
            ? null
            : session.hasError
            ? () => ref.invalidate(accountSessionProvider)
            : user == null
            ? () => context.go('/sign-in?from=%2Fsettings')
            : _signOut;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: StackCardSpacing.sm,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: context.colors.textSecondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: StackCardSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            liveRegion: !ready,
                            child: Text(
                              title,
                              maxLines: ready ? 2 : null,
                              overflow: ready ? TextOverflow.ellipsis : null,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (ready && user?.hasGoogle == true) ...[
                            const SizedBox(height: StackCardSpacing.xs),
                            Text(
                              strings.tr('account.googleProvider'),
                              key: const Key('account.googleProvider'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: context.colors.textSecondary,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: StackCardSpacing.sm),
                    if (session.isLoading)
                      const SizedBox(
                        width: StackCardSize.touchTarget,
                        height: StackCardSize.touchTarget,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (compact)
                      IconButton(
                        key: const Key('account.sessionAction'),
                        tooltip: actionLabel,
                        constraints: const BoxConstraints(
                          minWidth: StackCardSize.touchTarget,
                          minHeight: StackCardSize.touchTarget,
                        ),
                        onPressed: action,
                        style: IconButton.styleFrom(
                          foregroundColor: ready && user != null
                              ? context.colors.error
                              : context.colors.textPrimary,
                        ),
                        icon: busy
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ready && user != null
                                      ? context.colors.error
                                      : context.colors.textPrimary,
                                ),
                              )
                            : Icon(actionIcon, size: 24),
                      )
                    else
                      StackCardButton(
                        key: const Key('account.sessionAction'),
                        label: actionLabel,
                        role: ready && user != null
                            ? StackCardButtonRole.dangerQuiet
                            : StackCardButtonRole.quiet,
                        loading: busy,
                        onPressed: action,
                      ),
                  ],
                ),
              ),
            ),
            if (ready && errorKey != null) ...[
              const SizedBox(height: StackCardSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  strings.tr(errorKey),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.colors.error),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
