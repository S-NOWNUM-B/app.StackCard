import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
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
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                user == null ? Icons.devices_rounded : Icons.person_outline,
                color: context.colors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.tr(
                    user == null ? 'account.guestTitle' : 'account.title',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (session.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (session.hasError) ...[
            Semantics(
              liveRegion: true,
              child: Text(strings.tr('account.sessionError')),
            ),
            const SizedBox(height: 12),
            StackCardButton(
              label: strings.tr('common.retry'),
              onPressed: () => ref.invalidate(accountSessionProvider),
            ),
          ] else ...[
            if (user != null) ...[
              Text(
                user.email ??
                    user.displayName ??
                    strings.tr('account.signedIn'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              strings.tr(
                user == null ? 'account.guestNote' : 'account.localNote',
              ),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 20),
            StackCardButton(
              key: const Key('account.sessionAction'),
              label: strings.tr(
                user == null ? 'account.signIn' : 'account.signOut',
              ),
              icon: user == null ? Icons.login_rounded : Icons.logout_rounded,
              loading: busy,
              onPressed: busy
                  ? null
                  : user == null
                  ? () => context.go('/sign-in?from=%2Fsettings')
                  : _signOut,
            ),
            if (errorKey != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  strings.tr(errorKey),
                  style: TextStyle(color: context.colors.error),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
