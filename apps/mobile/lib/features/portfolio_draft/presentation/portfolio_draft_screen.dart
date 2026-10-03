import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/portfolio_draft_repository.dart';
import 'portfolio_draft_controller.dart';

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
                  Text(
                    strings.tr('draft.intro'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(
                    strings.tr('draft.scope'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: StackCardSpacing.xl),
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
                      }),
                    ),
                    if (!state.loaded)
                      StackCardButton(
                        label: strings.tr('draft.retryRead'),
                        onPressed: controller.load,
                      ),
                    if (state.hasUnsavedChanges)
                      Text(
                        strings.tr('draft.inputRetained'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    const SizedBox(height: StackCardSpacing.lg),
                  ],
                  StackCardCard(
                    child: Column(
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
                          label: strings.tr('draft.save'),
                          icon: Icons.save_outlined,
                          primary: true,
                          loading: state.saving,
                          onPressed: state.canSave ? controller.save : null,
                        ),
                      ],
                    ),
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
                  if (draft != null) ...[
                    const SizedBox(height: StackCardSpacing.sm),
                    Text(
                      strings.tr('draft.revision', {
                        'revision': draft.revision,
                      }),
                    ),
                    if (draft.updatedAt case final updatedAt?) ...[
                      const SizedBox(height: StackCardSpacing.sm),
                      Text(
                        strings.tr('draft.updatedAt', {
                          'time':
                              '${MaterialLocalizations.of(context).formatShortDate(updatedAt.toLocal())} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(updatedAt.toLocal()))}',
                        }),
                      ),
                    ],
                    if (draft.pendingSync) ...[
                      const SizedBox(height: StackCardSpacing.sm),
                      Text(
                        strings.tr('draft.pending'),
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: context.colors.textPrimary),
                      ),
                    ],
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
