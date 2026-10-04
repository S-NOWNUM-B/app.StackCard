import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/portfolio_draft_repository.dart';
import '../portfolio_draft_providers.dart';
import 'portfolio_builder_actions.dart';
import 'portfolio_builder_panels.dart';
import 'portfolio_draft_controller.dart';
import 'portfolio_draft_state.dart';
import 'portfolio_sync_status.dart';

class PortfolioBuilderScreen extends ConsumerWidget {
  const PortfolioBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioDraftControllerProvider);
    final controller = ref.read(portfolioDraftControllerProvider.notifier);
    final strings = context.strings;
    final cloudDraft = ref.watch(portfolioSyncRepositoryProvider) != null;
    final showSync = ref.watch(portfolioSyncVisibleProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('builder.title')),
        leading: IconButton(
          tooltip: strings.tr('builder.back'),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/portfolio'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(StackCardSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.tr(
                      cloudDraft ? 'sync.builderSubtitle' : 'builder.subtitle',
                    ),
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                  if (state.loading)
                    StackCardStateView(
                      kind: StackCardViewState.loading,
                      title: strings.tr('draft.loading'),
                      message: strings.tr('draft.loadingMessage'),
                    ),
                  if (state.failure case final failure?) ...[
                    StackCardStateView(
                      kind: StackCardViewState.error,
                      title: strings.tr(
                        state.loaded
                            ? 'builder.failure.title'
                            : 'draft.readFailure',
                      ),
                      message: strings.tr(switch (failure.kind) {
                        PortfolioDraftFailureKind.unavailable =>
                          'draft.unavailable',
                        PortfolioDraftFailureKind.corrupted =>
                          'draft.corrupted',
                        PortfolioDraftFailureKind.unsupportedVersion =>
                          'draft.unsupportedVersion',
                        PortfolioDraftFailureKind.conflict =>
                          'builder.failure.conflict',
                        PortfolioDraftFailureKind.invalidContent =>
                          'builder.failure.invalidContent',
                      }),
                      onRetry: state.loaded ? null : controller.load,
                    ),
                  ],
                  if (state.loaded && state.content == null) ...[
                    if (showSync) ...[
                      const PortfolioSyncStatusView(),
                      const SizedBox(height: StackCardSpacing.lg),
                    ],
                    StackCardStateView(
                      kind: StackCardViewState.empty,
                      title: strings.tr('builder.emptyTitle'),
                      message: strings.tr('builder.emptyMessage'),
                    ),
                    StackCardButton(
                      key: const ValueKey('builder_start'),
                      label: strings.tr('builder.start'),
                      primary: true,
                      onPressed: state.canEdit ? controller.startBuilder : null,
                    ),
                  ],
                  if (state.content != null) ...[
                    _DraftStatus(state: state),
                    const SizedBox(height: StackCardSpacing.lg),
                    StackCardButton(
                      key: const ValueKey('builder_save'),
                      label: strings.tr(
                        state.remoteUpdateAvailable
                            ? 'sync.saveMine'
                            : 'builder.save',
                      ),
                      icon: Icons.save_outlined,
                      primary: true,
                      loading: state.saving,
                      onPressed: state.canSave ? controller.save : null,
                    ),
                    const SizedBox(height: StackCardSpacing.sm),
                    StackCardButton(
                      key: const ValueKey('builder_preview'),
                      label: strings.tr('builder.preview'),
                      icon: Icons.visibility_outlined,
                      onPressed: () => context.push('/portfolio/preview'),
                    ),
                    if (state.validationCodes.isNotEmpty) ...[
                      const SizedBox(height: StackCardSpacing.sm),
                      Text(strings.tr('builder.invalid')),
                    ],
                    const SizedBox(height: StackCardSpacing.xl),
                    const PortfolioBuilderSections(),
                    const SizedBox(height: StackCardSpacing.xl),
                    const PortfolioBuilderProjects(),
                    const SizedBox(height: StackCardSpacing.xl),
                    const PortfolioBuilderBlocks(),
                    const SizedBox(height: StackCardSpacing.xl),
                    const PortfolioBuilderTheme(),
                  ],
                  const SizedBox(height: StackCardSpacing.xl),
                  StackCardButton(
                    label: strings.tr('builder.notes'),
                    icon: Icons.notes_rounded,
                    onPressed: () => context.push('/portfolio-draft'),
                  ),
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(strings.tr('builder.notesPrivate')),
                  if (state.loaded) ...[
                    const SizedBox(height: StackCardSpacing.xl),
                    StackCardButton(
                      key: const ValueKey('builder_reload'),
                      label: strings.tr('builder.reload'),
                      icon: Icons.refresh_rounded,
                      onPressed: state.saving
                          ? null
                          : () => confirmDraftReload(context, controller),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DraftStatus extends ConsumerWidget {
  const _DraftStatus({required this.state});
  final PortfolioDraftState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final completion = state.completion!;
    final showSync = ref.watch(portfolioSyncVisibleProvider);
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              strings.tr(
                state.saving
                    ? 'builder.saving'
                    : state.hasUnsavedChanges
                    ? 'builder.unsaved'
                    : 'builder.saved',
              ),
              key: const ValueKey('builder_status'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (state.draft case final draft?) ...[
            const SizedBox(height: StackCardSpacing.sm),
            Text(strings.tr('builder.revision', {'revision': draft.revision})),
            if (draft.pendingSync && !showSync)
              Text(strings.tr('builder.pending')),
          ],
          if (showSync) ...[
            const SizedBox(height: StackCardSpacing.sm),
            const PortfolioSyncStatusView(),
          ],
          if (state.remoteUpdateAvailable) ...[
            const SizedBox(height: StackCardSpacing.sm),
            Text(
              strings.tr('sync.remoteUpdate'),
              key: const ValueKey('portfolio_remote_update'),
            ),
          ],
          const SizedBox(height: StackCardSpacing.lg),
          Text(
            strings.tr('builder.completion', {'percent': completion.percent}),
            key: const ValueKey('builder_completion'),
          ),
          const SizedBox(height: StackCardSpacing.sm),
          LinearProgressIndicator(value: completion.fraction),
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            strings.tr('builder.completionCount', {
              'completed': completion.completedSteps,
              'total': completion.totalSteps,
            }),
          ),
          if (completion.missingSteps.isNotEmpty)
            Text(
              strings.tr('builder.completionMissing', {
                'steps': completion.missingSteps
                    .map((step) => strings.tr('builder.step.${step.name}'))
                    .join(', '),
              }),
            ),
        ],
      ),
    );
  }
}
