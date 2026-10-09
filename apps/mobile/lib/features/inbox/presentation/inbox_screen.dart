import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../../settings/settings_screen.dart';
import '../domain/contact_request.dart';
import '../inbox_providers.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inboxControllerProvider), strings = context.strings;
    final controller = ref.read(inboxControllerProvider.notifier);
    return SettingsEditorScaffold(
      title: strings.tr('inbox.title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.tr('inbox.hint')),
          const SizedBox(height: StackCardSpacing.lg),
          if (state.loading)
            StackCardStateView(
              kind: StackCardViewState.loading,
              title: strings.tr('common.loading'),
              message: strings.tr('inbox.loading'),
            ),
          if (state.failure != null)
            _InboxFailureView(
              failure: state.failure!,
              retry: () => controller.load(),
            ),
          if (state.loaded && state.requests.isEmpty && state.failure == null)
            StackCardStateView(
              kind: StackCardViewState.empty,
              title: strings.tr('inbox.empty'),
              message: strings.tr('inbox.emptyHint'),
            ),
          for (final request in state.requests)
            Padding(
              padding: const EdgeInsets.only(bottom: StackCardSpacing.md),
              child: StackCardCard(
                child: TextButton(
                  key: Key('inbox.request.${request.requestId}'),
                  onPressed: () => context.push('/inbox/${request.requestId}'),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.documentTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(request.name),
                        Text(request.email),
                        Text(
                          request.unread
                              ? strings.tr('inbox.unread')
                              : strings.tr('inbox.read'),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (state.cursor != null)
            StackCardButton(
              key: const Key('inbox.more'),
              label: strings.tr('inbox.more'),
              loading: state.loadingMore,
              onPressed: () => controller.load(more: true),
            ),
          if (!state.loading)
            Padding(
              padding: const EdgeInsets.only(top: StackCardSpacing.md),
              child: StackCardButton(
                label: strings.tr('inbox.refresh'),
                role: StackCardButtonRole.secondary,
                onPressed: () => controller.load(),
              ),
            ),
        ],
      ),
    );
  }
}

class InboxRequestScreen extends ConsumerStatefulWidget {
  const InboxRequestScreen({super.key, required this.requestId});
  final String requestId;
  @override
  ConsumerState<InboxRequestScreen> createState() => _InboxRequestScreenState();
}

class _InboxRequestScreenState extends ConsumerState<InboxRequestScreen> {
  bool _reading = false;
  InboxFailure? _failure;
  Future<void> _markRead() async {
    final repository = ref.read(inboxRepositoryProvider);
    if (repository == null || _reading) return;
    setState(() {
      _reading = true;
      _failure = null;
    });
    try {
      await repository.markRead(widget.requestId);
      if (!mounted || ref.read(inboxRepositoryProvider) != repository) return;
      ref.invalidate(inboxRequestProvider(widget.requestId));
      ref.read(inboxControllerProvider.notifier).load();
    } catch (error) {
      if (mounted && ref.read(inboxRepositoryProvider) == repository) {
        setState(() {
          _failure = error is InboxFailure
              ? error
              : const InboxFailure(InboxFailureKind.unavailable);
        });
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(inboxRequestProvider(widget.requestId));
    final strings = context.strings;
    return SettingsEditorScaffold(
      title: strings.tr('inbox.requestTitle'),
      onBack: () => context.canPop() ? context.pop() : context.go('/inbox'),
      child: value.when(
        loading: () => StackCardStateView(
          kind: StackCardViewState.loading,
          title: strings.tr('common.loading'),
          message: strings.tr('inbox.loading'),
        ),
        error: (error, _) => _InboxFailureView(
          failure: error is InboxFailure
              ? error
              : const InboxFailure(InboxFailureKind.unavailable),
          retry: () => ref.invalidate(inboxRequestProvider(widget.requestId)),
        ),
        data: (request) => request == null
            ? StackCardStateView(
                kind: StackCardViewState.unavailable,
                title: strings.tr('inbox.missing'),
                message: strings.tr('inbox.missingHint'),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    request.documentTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                  SelectableText(
                    request.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SelectableText(request.email),
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(
                    strings.tr('inbox.unverified'),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.colors.textSecondary),
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                  SelectableText(request.message),
                  const SizedBox(height: StackCardSpacing.md),
                  Text(request.createdAt.toLocal().toString()),
                  const SizedBox(height: StackCardSpacing.lg),
                  if (request.unread)
                    StackCardButton(
                      key: const Key('inbox.markRead'),
                      label: strings.tr('inbox.markRead'),
                      loading: _reading,
                      onPressed: _markRead,
                    )
                  else
                    Text(strings.tr('inbox.read')),
                  if (_failure != null)
                    _InboxFailureView(failure: _failure!, retry: _markRead),
                ],
              ),
      ),
    );
  }
}

class _InboxFailureView extends StatelessWidget {
  const _InboxFailureView({required this.failure, required this.retry});
  final InboxFailure failure;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => StackCardStateView(
    kind: failure.kind == InboxFailureKind.unavailable
        ? StackCardViewState.unavailable
        : StackCardViewState.error,
    title: context.strings.tr('inbox.error'),
    message: context.strings.tr('inbox.error.${failure.kind.name}'),
    onRetry: retry,
  );
}
