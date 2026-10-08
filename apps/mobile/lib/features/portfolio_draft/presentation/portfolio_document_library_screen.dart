import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_draft_repository.dart';
import '../portfolio_draft_providers.dart';
import '../../auth/auth.dart';
import '../document_publication_providers.dart';
import 'portfolio_document_publication_screen.dart';
import 'portfolio_draft_controller.dart';

class PortfolioDocumentLibraryScreen extends ConsumerWidget {
  const PortfolioDocumentLibraryScreen({super.key, required this.kind});
  final PortfolioDocumentKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) => WorkspaceReadGate(
    data: (content) {
      final isResume = kind == PortfolioDocumentKind.resume;
      final documents =
          content.documents.where((item) => item.kind == kind).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final state = ref.watch(portfolioDraftControllerProvider);
      return ListView(
        padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
        children: [
          StackCardButton(
            key: ValueKey(
              isResume ? 'workspace.createResume' : 'workspace.createPortfolio',
            ),
            label: context.strings.tr(
              isResume ? 'workspace.createResume' : 'workspace.createPortfolio',
            ),
            primary: true,
            onPressed:
                state.canEdit &&
                    !state.saving &&
                    content.documents.length < portfolioDocumentLimit
                ? () =>
                      context.push(isResume ? '/resumes/new' : '/portfolio/new')
                : null,
            unavailableReason: context.strings.tr('workspace.documentLimit', {
              'count': portfolioDocumentLimit,
            }),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          if (documents.isEmpty)
            StackCardStateView(
              kind: StackCardViewState.empty,
              title: context.strings.tr(
                isResume
                    ? 'workspace.emptyResumes'
                    : 'workspace.emptyPortfolios',
              ),
              message: context.strings.tr('workspace.emptyDocumentsHint'),
            ),
          for (final document in documents) ...[
            PortfolioDocumentCard(document: document),
            const SizedBox(height: StackCardSpacing.lg),
          ],
          if (content.documents.isEmpty &&
              (content.profile.name.isNotEmpty ||
                  content.projects.isNotEmpty ||
                  content.resumeText.isNotEmpty)) ...[
            Text(context.strings.tr('workspace.legacyHint')),
            const SizedBox(height: StackCardSpacing.md),
            StackCardButton(
              label: context.strings.tr('workspace.importLegacy'),
              loading: state.saving,
              onPressed: state.canEdit && !state.saving
                  ? () async {
                      await ref
                          .read(portfolioDraftControllerProvider.notifier)
                          .importLegacyDocuments(
                            portfolioTitle: context.strings.tr(
                              'workspace.legacyTitle',
                            ),
                            resumeTitle: context.strings.tr(
                              'workspace.legacyResumeTitle',
                            ),
                            expectedRepository: ref.read(
                              portfolioDraftRepositoryProvider,
                            ),
                          );
                    }
                  : null,
            ),
          ],
        ],
      );
    },
  );
}

class PortfolioDocumentCard extends ConsumerWidget {
  const PortfolioDocumentCard({super.key, required this.document});
  final PortfolioDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final isResume = document.kind == PortfolioDocumentKind.resume;
    final state = ref.watch(portfolioDraftControllerProvider);
    final publicationState = ref.watch(documentPublicationControllerProvider);
    final publication = publicationState.forDocument(document.id);
    final unknown = publicationState.pending?.documentId == document.id;
    final url = unknown ? null : publication?.shareableUrl;
    void openPublication() => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PortfolioDocumentPublicationScreen(documentId: document.id),
      ),
    );
    return StackCardCard(
      outlined: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('document.open.${document.id}'),
            borderRadius: BorderRadius.circular(StackCardRadius.large),
            onTap: () => context.push(
              '${isResume ? '/resumes' : '/portfolio'}/${Uri.encodeComponent(document.id)}/edit',
            ),
            child: Padding(
              padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StackCardIcon(
                        name: isResume ? 'file-text' : 'panels-top-left',
                        size: 20,
                        color: context.colors.accentText,
                      ),
                      const SizedBox(width: StackCardSpacing.sm),
                      Text(
                        strings
                            .tr(
                              isResume
                                  ? 'workspace.resume'
                                  : 'workspace.portfolio',
                            )
                            .toUpperCase(),
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: StackCardSpacing.md),
                  Text(
                    document.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (document.content.profile.headline.isNotEmpty) ...[
                    const SizedBox(height: StackCardSpacing.md),
                    Text(
                      document.content.profile.headline,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: context.colors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: StackCardSpacing.md),
                  Text(
                    workspaceDate(context, document.updatedAt),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.colors.textMeta),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              StackCardSpacing.cardPadding,
              0,
              StackCardSpacing.cardPadding,
              StackCardSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.tr(
                          unknown
                              ? 'documentPublication.unknown'
                              : publication == null
                              ? 'workspace.draft'
                              : 'documentPublication.${publication.visibility.name}',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: url == null
                              ? null
                              : context.colors.successText,
                        ),
                      ),
                      Text(
                        strings.tr(
                          unknown
                              ? 'documentPublication.unknown'
                              : url == null
                              ? 'workspace.linkAfterPublish'
                              : 'documentPublication.linkHint',
                        ),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: context.colors.textMeta),
                      ),
                    ],
                  ),
                ),
                if (url != null)
                  StackCardButton(
                    key: ValueKey('document.copy.${document.id}'),
                    label: strings.tr('documentPublication.copy'),
                    iconWidget: const StackCardIcon(name: 'copy', size: 20),
                    onPressed: publicationState.loading || publicationState.busy
                        ? null
                        : () async {
                            final repository = ref.read(
                              documentPublicationRepositoryProvider,
                            );
                            try {
                              final current = ref.read(
                                documentPublicationControllerProvider,
                              );
                              if (current.pending?.documentId == document.id ||
                                  current
                                          .forDocument(document.id)
                                          ?.shareableUrl !=
                                      url) {
                                return;
                              }
                              await Clipboard.setData(
                                ClipboardData(text: url.toString()),
                              );
                              if (!context.mounted ||
                                  !identical(
                                    repository,
                                    ref.read(
                                      documentPublicationRepositoryProvider,
                                    ),
                                  ) ||
                                  ref
                                          .read(
                                            documentPublicationControllerProvider,
                                          )
                                          .forDocument(document.id)
                                          ?.shareableUrl !=
                                      url) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    strings.tr('documentPublication.copied'),
                                  ),
                                ),
                              );
                            } on Object {
                              if (context.mounted &&
                                  identical(
                                    repository,
                                    ref.read(
                                      documentPublicationRepositoryProvider,
                                    ),
                                  )) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      strings.tr(
                                        'documentPublication.actionFailed',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                  ),
                PopupMenuButton<String>(
                  key: ValueKey('document.actions.${document.id}'),
                  tooltip: strings.tr('builderIntegration.edit'),
                  enabled: state.canEdit && !state.saving,
                  constraints: const BoxConstraints(minWidth: 180),
                  icon: const StackCardIcon(name: 'more-horizontal'),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'publication',
                      child: Text(strings.tr('documentPublication.title')),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      enabled:
                          (state.content?.documents.length ?? 0) <
                          portfolioDocumentLimit,
                      child: Text(strings.tr('workspace.duplicate')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(strings.tr('workspace.delete')),
                    ),
                  ],
                  onSelected: (action) async {
                    if (action == 'publication') {
                      openPublication();
                      return;
                    }
                    final repository = ref.read(
                      portfolioDraftRepositoryProvider,
                    );
                    final controller = ref.read(
                      portfolioDraftControllerProvider.notifier,
                    );
                    if (action == 'duplicate') {
                      final now = DateTime.now().toUtc();
                      final title = strings.tr('workspace.copyTitle', {
                        'title': document.title,
                      });
                      await controller.saveDocument(
                        document.copyWith(
                          id: controller.createId(),
                          title: title.length > 120
                              ? title.substring(0, 120)
                              : title,
                          createdAt: now,
                          updatedAt: now,
                        ),
                        expectedRepository: repository,
                      );
                    } else {
                      final session = ref.read(accountSessionProvider);
                      if (!session.isLoading &&
                          !session.hasError &&
                          session.value?.uid != null) {
                        // Account deletion сначала отзывает public snapshot и ставит tombstone.
                        openPublication();
                        return;
                      }
                      final accepted = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(strings.tr('workspace.deleteTitle')),
                          content: Text(strings.tr('workspace.deleteHint')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(strings.tr('builder.cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(strings.tr('workspace.delete')),
                            ),
                          ],
                        ),
                      );
                      if (accepted == true && context.mounted) {
                        await controller.deleteDocument(
                          document,
                          expectedRepository: repository,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String workspaceDate(BuildContext context, DateTime? value) {
  if (value == null) return context.strings.tr('workspace.noDate');
  final local = value.toLocal();
  final localization = MaterialLocalizations.of(context);
  final date = localization.formatMediumDate(local);
  final time = localization.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return context.strings.tr('workspace.modified', {'date': '$date, $time'});
}

class WorkspaceReadGate extends ConsumerWidget {
  const WorkspaceReadGate({super.key, required this.data});
  final Widget Function(PortfolioContent) data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioDraftControllerProvider);
    if (state.loading || !state.loaded) {
      if (state.failure != null && !state.loading) {
        return SingleChildScrollView(
          child: StackCardStateView(
            kind: StackCardViewState.error,
            title: context.strings.tr('draft.readFailure'),
            message: context.strings.tr(switch (state.failure!.kind) {
              PortfolioDraftFailureKind.corrupted => 'draft.corrupted',
              PortfolioDraftFailureKind.unsupportedVersion =>
                'draft.unsupportedVersion',
              _ => 'draft.unavailable',
            }),
            onRetry: ref.read(portfolioDraftControllerProvider.notifier).load,
          ),
        );
      }
      return SingleChildScrollView(
        child: StackCardStateView(
          kind: StackCardViewState.loading,
          title: context.strings.tr('draft.loading'),
          message: context.strings.tr('draft.loadingMessage'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.failure != null)
          Padding(
            padding: const EdgeInsets.all(StackCardSpacing.md),
            child: Text(
              context.strings.tr(
                state.failure!.kind == PortfolioDraftFailureKind.conflict
                    ? 'builder.failure.conflict'
                    : 'workspace.failure',
              ),
              style: TextStyle(color: context.colors.error),
            ),
          ),
        Expanded(child: data(state.content ?? PortfolioContent())),
      ],
    );
  }
}
