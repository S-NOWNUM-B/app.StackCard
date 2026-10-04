import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_theme.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_draft_repository.dart';
import 'portfolio_content_view.dart';
import 'portfolio_draft_controller.dart';

class PortfolioPreviewScreen extends ConsumerWidget {
  const PortfolioPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioDraftControllerProvider);
    final content = state.content;
    return Theme(
      data: content?.theme == PortfolioTheme.light
          ? StackCardTheme.light
          : StackCardTheme.dark,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(context.strings.tr('builder.previewTitle')),
            leading: IconButton(
              tooltip: context.strings.tr('builder.backEditor'),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/portfolio/builder'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(StackCardSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.strings.tr('builder.previewPrivate'),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: StackCardSpacing.sm),
                            if (state.loaded && content != null)
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  context.strings.tr(
                                    state.saving
                                        ? 'builder.saving'
                                        : state.hasUnsavedChanges
                                        ? 'builder.unsaved'
                                        : 'builder.saved',
                                  ),
                                  key: const ValueKey(
                                    'portfolio_preview_status',
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (state.failure case final failure?)
                        StackCardStateView(
                          kind: StackCardViewState.error,
                          title: context.strings.tr(
                            state.loaded
                                ? 'builder.failure.title'
                                : 'draft.readFailure',
                          ),
                          message: context.strings.tr(switch (failure.kind) {
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
                          onRetry: state.loaded
                              ? null
                              : ref
                                    .read(
                                      portfolioDraftControllerProvider.notifier,
                                    )
                                    .load,
                        ),
                      if (content != null)
                        PortfolioContentView(content: content)
                      else if (state.failure == null)
                        StackCardStateView(
                          kind: state.loading
                              ? StackCardViewState.loading
                              : StackCardViewState.empty,
                          title: context.strings.tr(
                            state.loading
                                ? 'draft.loading'
                                : 'builder.emptyTitle',
                          ),
                          message: context.strings.tr(
                            state.loading
                                ? 'draft.loadingMessage'
                                : 'builder.emptyMessage',
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(StackCardSpacing.lg),
                        child: StackCardButton(
                          label: context.strings.tr('builder.backEditor'),
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/portfolio/builder'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
