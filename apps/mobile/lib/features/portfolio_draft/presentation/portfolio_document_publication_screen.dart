import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../auth/auth.dart';
import '../document_publication_providers.dart';
import '../domain/document_publication.dart';
import '../domain/portfolio_content.dart';
import '../portfolio_draft_providers.dart';
import 'portfolio_draft_controller.dart';

/// R5.4a/b/c: local commit, exact server ACK и public inventory независимы.
class PortfolioDocumentPublicationScreen extends ConsumerStatefulWidget {
  const PortfolioDocumentPublicationScreen({
    super.key,
    required this.documentId,
    this.editorDirty = false,
  });

  final String documentId;
  final bool editorDirty;

  @override
  ConsumerState<PortfolioDocumentPublicationScreen> createState() =>
      _PortfolioDocumentPublicationScreenState();
}

class _PortfolioDocumentPublicationScreenState
    extends ConsumerState<PortfolioDocumentPublicationScreen> {
  var _linkBusy = false;
  var _copied = false;
  var _linkError = false;

  String _tr(String key) => context.strings.tr('documentPublication.$key');

  Future<void> _linkAction(String action, Uri url) async {
    if (_linkBusy) return;
    final repository = ref.read(documentPublicationRepositoryProvider);
    setState(() {
      _linkBusy = true;
      _copied = false;
      _linkError = false;
    });
    try {
      if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: url.toString()));
      } else {
        final actions = ref.read(documentLinkActionsProvider);
        if (actions == null) throw const FormatException();
        if (action == 'open') {
          await actions.open(url);
        } else {
          await actions.share(url);
        }
      }
      if (!mounted ||
          !identical(
            repository,
            ref.read(documentPublicationRepositoryProvider),
          )) {
        return;
      }
      final current = ref
          .read(documentPublicationControllerProvider)
          .forDocument(widget.documentId)
          ?.shareableUrl;
      if (current == url) setState(() => _copied = action == 'copy');
    } on Object {
      if (mounted &&
          identical(
            repository,
            ref.read(documentPublicationRepositoryProvider),
          )) {
        setState(() => _linkError = true);
      }
    } finally {
      if (mounted) setState(() => _linkBusy = false);
    }
  }

  Future<void> _confirm(DocumentPublicationAction action) async {
    final deleting = action == DocumentPublicationAction.deleteDocument;
    final repository = ref.read(documentPublicationRepositoryProvider);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(_tr(deleting ? 'deleteTitle' : 'unpublishTitle')),
        content: Text(_tr(deleting ? 'deleteHint' : 'unpublishHint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.tr('builder.cancel')),
          ),
          TextButton(
            key: const ValueKey('publication.confirm'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: Text(_tr(deleting ? 'delete' : 'unpublish')),
          ),
        ],
      ),
    );
    if (!mounted ||
        accepted != true ||
        !identical(
          repository,
          ref.read(documentPublicationRepositoryProvider),
        )) {
      return;
    }
    final completed = await ref
        .read(documentPublicationControllerProvider.notifier)
        .perform(action: action, documentId: widget.documentId);
    if (completed &&
        deleting &&
        mounted &&
        identical(
          repository,
          ref.read(documentPublicationRepositoryProvider),
        )) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final publicationState = ref.watch(documentPublicationControllerProvider);
    final repository = ref.watch(documentPublicationRepositoryProvider);
    final draft = ref.watch(portfolioDraftControllerProvider);
    final expectedMutation = ref.watch(
      documentPublicationExpectedMutationProvider,
    );
    final session = ref.watch(accountSessionProvider);
    final account = !session.isLoading && !session.hasError
        ? session.value
        : null;
    final document = draft.draft?.content?.documents
        .where((item) => item.id == widget.documentId)
        .firstOrNull;
    final publication = publicationState.forDocument(widget.documentId);
    final deleted =
        publication?.visibility == DocumentPublicationVisibility.deleted;
    final dirty = widget.editorDirty || draft.hasUnsavedChanges;
    final pending = publicationState.pending;
    final unknownDocument = pending?.documentId == widget.documentId;
    final url = unknownDocument ? null : publication?.shareableUrl;
    final enabled =
        !dirty &&
        !deleted &&
        document != null &&
        expectedMutation != null &&
        publicationState.canMutate &&
        repository != null;
    final canWithdraw =
        !deleted &&
        document != null &&
        publicationState.canMutate &&
        repository != null;
    final canDelete = canWithdraw && !draft.saving;
    final reason = account == null
        ? _tr('guest')
        : repository == null
        ? _tr('unconfigured')
        : dirty
        ? _tr('saveFirstHint')
        : expectedMutation == null
        ? _tr('pendingSyncHint')
        : _tr('linkUnavailable');
    final status = unknownDocument
        ? 'unknown'
        : publication?.visibility.name ?? 'draft';
    final controller = ref.read(documentPublicationControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('title')),
        leading: IconButton(
          tooltip: context.strings.tr('documentEditor.back'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const StackCardIcon(name: 'arrow-left'),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: StackCardSize.contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
              children: [
                if (document != null) ...[
                  StackCardCard(
                    outlined: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            StackCardIcon(
                              name:
                                  document.kind == PortfolioDocumentKind.resume
                                  ? 'file-text'
                                  : 'panels-top-left',
                              size: 20,
                              color: context.colors.accentText,
                            ),
                            const SizedBox(width: StackCardSpacing.sm),
                            Expanded(
                              child: Text(
                                document.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: StackCardSpacing.md),
                        Text(
                          document.content.profile.headline,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                ],
                _statusCard(
                  status,
                  '${status}Hint',
                  confirmed:
                      !unknownDocument &&
                      publication?.visibility ==
                          DocumentPublicationVisibility.published,
                ),
                const SizedBox(height: StackCardSpacing.lg),
                if (document != null && !dirty) ...[
                  _statusCard('localSaved', 'localSavedHint'),
                  const SizedBox(height: StackCardSpacing.lg),
                ],
                if (dirty) ...[
                  _statusCard('saveFirst', 'saveFirstHint'),
                  const SizedBox(height: StackCardSpacing.lg),
                ] else if (expectedMutation != null) ...[
                  _statusCard(
                    'synced',
                    'syncedHint',
                    confirmed: true,
                    sync: true,
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                ] else if (account != null &&
                    repository != null &&
                    !deleted) ...[
                  _statusCard('pendingSync', 'pendingSyncHint'),
                  StackCardButton(
                    key: const ValueKey('publication.retrySync'),
                    label: _tr('retrySync'),
                    onPressed: ref
                        .watch(portfolioSyncRepositoryProvider)
                        ?.retry,
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                ],
                if (account == null || repository == null) ...[
                  Text(reason),
                  const SizedBox(height: StackCardSpacing.lg),
                ],
                if (publicationState.loading) ...[
                  Semantics(liveRegion: true, child: Text(_tr('loading'))),
                  const LinearProgressIndicator(),
                  const SizedBox(height: StackCardSpacing.lg),
                ],
                if (pending != null) ...[
                  if (!unknownDocument) _statusCard('unknown', 'unknownHint'),
                  const SizedBox(height: StackCardSpacing.md),
                  Wrap(
                    spacing: StackCardSpacing.sm,
                    runSpacing: StackCardSpacing.sm,
                    children: [
                      StackCardButton(
                        key: const ValueKey('publication.checkStatus'),
                        label: _tr('checkStatus'),
                        loading: publicationState.busy,
                        onPressed: publicationState.busy
                            ? null
                            : controller.checkOperation,
                      ),
                      StackCardButton(
                        key: const ValueKey('publication.retryOperation'),
                        label: _tr('retryOperation'),
                        onPressed: publicationState.busy
                            ? null
                            : controller.retryOperation,
                      ),
                    ],
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                ],
                if (publicationState.failure case final failure?) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _tr('error.${failure.kind.name}'),
                      style: TextStyle(color: context.colors.error),
                    ),
                  ),
                  const SizedBox(height: StackCardSpacing.md),
                ],
                if (repository != null)
                  StackCardButton(
                    label: _tr('refresh'),
                    onPressed: publicationState.busy || publicationState.loading
                        ? null
                        : controller.load,
                  ),
                if (url != null) ...[
                  const SizedBox(height: StackCardSpacing.lg),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: SelectableText(url.toString()),
                  ),
                  const SizedBox(height: StackCardSpacing.md),
                  StackCardButton(
                    key: const ValueKey('publication.copy'),
                    label: _tr(_copied ? 'copied' : 'copy'),
                    iconWidget: const StackCardIcon(name: 'copy', size: 20),
                    onPressed: _linkBusy
                        ? null
                        : () => _linkAction('copy', url),
                  ),
                  const SizedBox(height: StackCardSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: StackCardButton(
                          key: const ValueKey('publication.open'),
                          label: _tr('open'),
                          onPressed:
                              _linkBusy ||
                                  ref.watch(documentLinkActionsProvider) == null
                              ? null
                              : () => _linkAction('open', url),
                        ),
                      ),
                      const SizedBox(width: StackCardSpacing.sm),
                      Expanded(
                        child: StackCardButton(
                          key: const ValueKey('publication.share'),
                          label: _tr('share'),
                          onPressed:
                              _linkBusy ||
                                  ref.watch(documentLinkActionsProvider) == null
                              ? null
                              : () => _linkAction('share', url),
                        ),
                      ),
                    ],
                  ),
                  if (ref.watch(documentLinkActionsProvider) == null)
                    Text(_tr('linkActionsUnavailable')),
                  if (_linkError)
                    Text(
                      _tr('actionFailed'),
                      style: TextStyle(color: context.colors.error),
                    ),
                  const SizedBox(height: StackCardSpacing.md),
                  Text(_tr('linkHint')),
                ],
                if (document != null && !deleted) ...[
                  const SizedBox(height: StackCardSpacing.lg),
                  StackCardCard(
                    outlined: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _tr('summary'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: StackCardSpacing.md),
                        Text(_tr('summaryHint')),
                      ],
                    ),
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                  Text(_tr('consent')),
                  if (publication?.visibility ==
                      DocumentPublicationVisibility.published)
                    StackCardButton(
                      key: const ValueKey('publication.unpublish'),
                      label: _tr('unpublish'),
                      role: StackCardButtonRole.danger,
                      onPressed: canWithdraw
                          ? () => _confirm(DocumentPublicationAction.unpublish)
                          : null,
                      unavailableReason: canWithdraw ? null : reason,
                    ),
                  StackCardButton(
                    key: const ValueKey('publication.delete'),
                    label: _tr('delete'),
                    role: StackCardButtonRole.danger,
                    onPressed: canDelete
                        ? () =>
                              _confirm(DocumentPublicationAction.deleteDocument)
                        : null,
                    unavailableReason: draft.saving
                        ? context.strings.tr('builder.saving')
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: document == null || deleted
          ? null
          : ColoredBox(
              color: context.colors.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: StackCardButton(
                          label: context.strings.tr('builder.cancel'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: StackCardSpacing.sm),
                      Expanded(
                        child: StackCardButton(
                          key: const ValueKey('publication.publish'),
                          label: _tr(
                            publication?.visibility ==
                                    DocumentPublicationVisibility.published
                                ? 'republish'
                                : 'publish',
                          ),
                          primary: true,
                          loading: publicationState.busy,
                          onPressed: enabled
                              ? () => controller.perform(
                                  action: DocumentPublicationAction.publish,
                                  documentId: widget.documentId,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _statusCard(
    String heading,
    String hint, {
    bool confirmed = false,
    bool sync = false,
  }) => StackCardCard(
    elevated: true,
    padding: const EdgeInsets.all(StackCardSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (confirmed) ...[
              StackCardIcon(
                name: 'check',
                color: sync
                    ? context.colors.successText
                    : context.colors.accentText,
              ),
              const SizedBox(width: StackCardSpacing.sm),
            ],
            Expanded(
              child: Text(
                _tr(heading),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: confirmed
                      ? sync
                            ? context.colors.successText
                            : context.colors.accentText
                      : context.colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: StackCardSpacing.sm),
        Text(
          _tr(hint),
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.colors.textSecondary),
        ),
      ],
    ),
  );
}
