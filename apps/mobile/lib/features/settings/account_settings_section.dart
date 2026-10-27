import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../shared/widgets/stackcard_dialog_actions.dart';
import '../auth/auth.dart';
import '../portfolio_draft/portfolio_draft.dart';

class AccountSettingsSection extends ConsumerWidget {
  const AccountSettingsSection({super.key});

  Future<bool> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final draft = ref.read(portfolioDraftControllerProvider);
    if (draft.saving) return false;
    if (!draft.hasUnsavedChanges) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(context.strings.tr('account.unsavedTitle')),
            content: Text(context.strings.tr('account.unsavedHint')),
            actions: [
              StackCardDialogActions(
                onCancel: () => Navigator.pop(context, false),
                onConfirm: () => Navigator.pop(context, true),
                confirmLabel: context.strings.tr('account.discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AccountCard(beforeSignOut: () => _confirmSignOut(context, ref));
}
