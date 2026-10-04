import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_card.dart';
import '../auth/auth.dart';
import '../portfolio_draft/portfolio_draft.dart';

class AccountSettingsSection extends ConsumerStatefulWidget {
  const AccountSettingsSection({super.key});
  @override
  ConsumerState<AccountSettingsSection> createState() =>
      _AccountSettingsSectionState();
}

class _AccountSettingsSectionState
    extends ConsumerState<AccountSettingsSection> {
  bool _transferring = false;
  String? _message;

  AuthUser? _readyUser() {
    final session = ref.read(accountSessionProvider);
    return !session.isLoading && !session.hasError ? session.value : null;
  }

  Future<bool> _confirmSignOut() async {
    final draft = ref.read(portfolioDraftControllerProvider);
    if (draft.saving || _transferring) return false;
    if (!draft.hasUnsavedChanges) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.strings.tr('account.unsavedTitle')),
            content: Text(context.strings.tr('account.unsavedHint')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.strings.tr('account.cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.strings.tr('account.discard')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _transfer() async {
    if (_transferring) return;
    final user = _readyUser();
    final transfer = ref.read(guestDraftTransferProvider);
    final draft = ref.read(portfolioDraftControllerProvider);
    if (user == null || transfer == null || draft.saving) return;
    if (draft.hasUnsavedChanges) {
      setState(() => _message = 'account.transferUnsaved');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.tr('account.transferTitle')),
        content: Text(context.strings.tr('account.transferConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.tr('account.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings.tr('account.transfer')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _readyUser()?.uid != user.uid) {
      return;
    }
    final confirmedDraft = ref.read(portfolioDraftControllerProvider);
    if (confirmedDraft.saving || confirmedDraft.hasUnsavedChanges) {
      setState(() => _message = 'account.transferUnsaved');
      return;
    }
    setState(() {
      _transferring = true;
      _message = null;
    });
    try {
      await transfer(user.uid);
      if (!mounted || _readyUser()?.uid != user.uid) {
        return;
      }
      ref.invalidate(guestDraftAvailableProvider);
      final latest = ref.read(portfolioDraftControllerProvider);
      if (latest.saving || latest.hasUnsavedChanges) {
        // New working edits belong to this account; never discard them on completion.
        setState(() => _message = 'account.transferWorkingPreserved');
      } else {
        ref.invalidate(portfolioDraftControllerProvider);
        setState(() => _message = 'account.transferSuccess');
      }
    } on PortfolioDraftFailure catch (failure) {
      if (mounted) {
        setState(
          () => _message = switch (failure.kind) {
            PortfolioDraftFailureKind.conflict => 'account.transferConflict',
            PortfolioDraftFailureKind.corrupted => 'draft.corrupted',
            PortfolioDraftFailureKind.unsupportedVersion =>
              'draft.unsupportedVersion',
            _ => 'draft.unavailable',
          },
        );
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'draft.unavailable');
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(accountSessionProvider);
    final user = !session.isLoading && !session.hasError ? session.value : null;
    final available = user == null
        ? const AsyncData(false)
        : ref.watch(guestDraftAvailableProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountCard(beforeSignOut: _confirmSignOut),
        if (user != null &&
            (available.value == true ||
                available.hasError ||
                _message != null)) ...[
          const SizedBox(height: 16),
          StackCardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.strings.tr('account.transferTitle'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(context.strings.tr('account.transferHint')),
                const SizedBox(height: 16),
                if (available.hasError)
                  StackCardButton(
                    label: context.strings.tr('common.retry'),
                    onPressed: () =>
                        ref.invalidate(guestDraftAvailableProvider),
                  )
                else if (available.value == true)
                  StackCardButton(
                    label: context.strings.tr('account.transfer'),
                    loading: _transferring,
                    onPressed: _transferring ? null : _transfer,
                  ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(context.strings.tr(_message!)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
