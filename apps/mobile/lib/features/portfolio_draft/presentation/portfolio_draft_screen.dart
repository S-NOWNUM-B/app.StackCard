import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_poster.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/portfolio_draft_repository.dart';
import '../portfolio_draft_providers.dart';
import 'portfolio_builder_actions.dart';
import 'portfolio_draft_controller.dart';
import 'portfolio_sync_status.dart';

class PortfolioDraftScreen extends ConsumerStatefulWidget {
  const PortfolioDraftScreen({super.key});

  @override
  ConsumerState<PortfolioDraftScreen> createState() =>
      _PortfolioDraftScreenState();
}

class _PortfolioDraftScreenState extends ConsumerState<PortfolioDraftScreen> {
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notesController.text = ref.read(portfolioDraftControllerProvider).notes;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioDraftControllerProvider);
    final controller = ref.read(portfolioDraftControllerProvider.notifier);
    final strings = context.strings;
    final draft = state.draft;
    final showSync = ref.watch(portfolioSyncVisibleProvider);
    ref.listen(
      portfolioDraftControllerProvider.select((state) => state.notes),
      (_, notes) {
        if (_notesController.text != notes) _notesController.text = notes;
      },
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('draft.title')),
        leading: IconButton(
          tooltip: strings.tr('draft.back'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/portfolio'),
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
                  StackCardPoster(
                    color: context.colors.pink,
                    art: false,
                    child: Text(
                      strings.tr('builder.notesPrivate'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: context.colors.ink),
                    ),
                  ),
                  const SizedBox(height: StackCardSpacing.xl),
                  if (state.remoteUpdateAvailable) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        strings.tr('sync.remoteUpdate'),
                        key: const ValueKey('portfolio_remote_update'),
                      ),
                    ),
                    const SizedBox(height: StackCardSpacing.sm),
                    StackCardButton(
                      key: const ValueKey('portfolio_draft_reload'),
                      label: strings.tr('builder.reload'),
                      onPressed: state.saving
                          ? null
                          : () => confirmDraftReload(context, controller),
                    ),
                    const SizedBox(height: StackCardSpacing.lg),
                  ],
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
                            ? 'draft.saveFailure'
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
                    ),
                    if (!state.loaded)
                      StackCardButton(
                        label: strings.tr('draft.retryRead'),
                        onPressed: controller.load,
                      ),
                    if (failure.kind == PortfolioDraftFailureKind.conflict)
                      StackCardButton(
                        label: strings.tr('builder.reload'),
                        onPressed: state.saving
                            ? null
                            : () => confirmDraftReload(context, controller),
                      ),
                    if (state.hasUnsavedChanges)
                      Text(
                        strings.tr('draft.inputRetained'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    const SizedBox(height: StackCardSpacing.lg),
                  ],
                  if (state.validationCodes.isNotEmpty) ...[
                    Text(strings.tr('builder.invalid')),
                    StackCardButton(
                      label: strings.tr('builder.title'),
                      onPressed: () => context.push('/portfolio/builder'),
                    ),
                    const SizedBox(height: StackCardSpacing.lg),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StackCardInput(
                        key: const ValueKey('portfolio_draft_notes'),
                        label: strings.tr('draft.notes'),
                        hint: strings.tr('draft.hint'),
                        controller: _notesController,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        minLines: 6,
                        maxLines: 12,
                        enabled: state.canEdit,
                        onChanged: controller.editNotes,
                      ),
                      const SizedBox(height: StackCardSpacing.lg),
                      StackCardButton(
                        key: const ValueKey('portfolio_draft_save'),
                        label: strings.tr(
                          state.remoteUpdateAvailable
                              ? 'sync.saveMine'
                              : 'draft.save',
                        ),
                        icon: Icons.save_outlined,
                        primary: true,
                        loading: state.saving,
                        onPressed: state.canSave ? controller.save : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                  if (!state.loading && state.loaded)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        strings.tr(
                          state.saving
                              ? 'draft.saving'
                              : state.hasUnsavedChanges
                              ? 'draft.unsaved'
                              : draft == null
                              ? 'draft.empty'
                              : 'draft.saved',
                        ),
                        key: const ValueKey('portfolio_draft_status'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  if (draft != null)
                    ExpansionTile(
                      key: const ValueKey('portfolio_draft_details'),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(
                        bottom: StackCardSpacing.lg,
                      ),
                      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                      title: Text(strings.tr('common.details')),
                      children: [
                        Text(
                          strings.tr('draft.revision', {
                            'revision': draft.revision,
                          }),
                        ),
                        if (draft.updatedAt case final updatedAt?)
                          Text(
                            strings.tr('draft.updatedAt', {
                              'time':
                                  '${MaterialLocalizations.of(context).formatShortDate(updatedAt.toLocal())} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(updatedAt.toLocal()))}',
                            }),
                          ),
                        if (draft.pendingSync && !showSync)
                          Text(strings.tr('draft.pending')),
                      ],
                    ),
                  if (showSync && state.loaded) ...[
                    const SizedBox(height: StackCardSpacing.sm),
                    const PortfolioSyncStatusView(),
                  ],
                  const SizedBox(height: StackCardSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
