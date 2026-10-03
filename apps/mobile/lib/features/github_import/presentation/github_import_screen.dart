import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' show SelectContext;

import '../../../core/localization/app_strings.dart';
import '../../../core/state/appearance_controller.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/github_filters.dart';
import 'github_cache_notice.dart';
import 'github_failure_view.dart';
import 'github_import_controller.dart';
import 'github_import_state.dart';
import 'github_source_cards.dart';

class GitHubImportScreen extends ConsumerStatefulWidget {
  const GitHubImportScreen({super.key});

  @override
  ConsumerState<GitHubImportScreen> createState() => _GitHubImportScreenState();
}

class _GitHubImportScreenState extends ConsumerState<GitHubImportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    ref
        .read(githubImportControllerProvider.notifier)
        .load(_usernameController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(githubImportControllerProvider);
    final controller = ref.read(githubImportControllerProvider.notifier);
    ref.listen(
      githubImportControllerProvider.select(
        (state) => (state.username, state.query),
      ),
      (_, selection) {
        final query = selection.$2;
        if (_searchController.text != query) {
          _searchController.text = query;
        }
      },
    );
    final repositories = state.visibleRepositories;
    final showDescriptions = context.select<AppearanceController, bool>(
      (controller) => controller.showSourceDescriptions,
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.background,
        title: const Text('GitHub Import'),
        leading: IconButton(
          tooltip: context.strings.tr('github.back'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/projects'),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: RefreshIndicator(
              onRefresh: state.username.isEmpty
                  ? () async {}
                  : controller.refresh,
              child: ListView.builder(
                key: const PageStorageKey('github_import_list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(StackCardSpacing.lg),
                itemCount: 2 + repositories.length,
                itemBuilder: (context, index) {
                  if (index == 0) return _header(context, state);
                  if (index == repositories.length + 1) return _footer(state);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: StackCardSpacing.lg),
                    child: GitHubRepositoryCard(
                      repository: repositories[index - 1],
                      showDescription: showDescriptions,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, GitHubImportState state) {
    final controller = ref.read(githubImportControllerProvider.notifier);
    final pageTextColor = Theme.of(context).brightness == Brightness.light
        ? context.colors.textPrimary
        : context.colors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.strings.tr('github.title'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: StackCardSpacing.sm),
        Text(
          context.strings.tr('github.hint'),
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: pageTextColor),
        ),
        const SizedBox(height: StackCardSpacing.xl),
        StackCardCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StackCardInput(
                  key: const ValueKey('github_username'),
                  label: context.strings.tr('github.username'),
                  hint: context.strings.tr('github.usernameHint'),
                  controller: _usernameController,
                  validator: (value) {
                    final failure = validateGitHubUsername(value);
                    if (failure == null) return null;
                    return context.strings.tr(
                      normalizeGitHubUsername(value ?? '').isEmpty
                          ? 'github.usernameEmpty'
                          : 'github.usernameInvalid',
                    );
                  },
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: StackCardSpacing.lg),
                StackCardButton(
                  label: context.strings.tr('github.load'),
                  icon: Icons.download_rounded,
                  primary: true,
                  loading: state.loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: StackCardSpacing.xl),
        if (state.loading)
          StackCardStateView(
            kind: StackCardViewState.loading,
            title: context.strings.tr('github.loading'),
            message: context.strings.tr('github.loadingHint'),
          ),
        if (state.failure case final failure?)
          GitHubFailureView(failure: failure, onRetry: controller.retry),
        if (state.profile case final profile?) ...[
          GitHubCacheNotice(metadata: state.readMetadata),
          GitHubProfileCard(profile: profile),
          const SizedBox(height: StackCardSpacing.lg),
          StackCardButton(
            label: context.strings.tr('github.refresh'),
            icon: Icons.refresh_rounded,
            loading: state.refreshing,
            onPressed: state.loading ? null : controller.refresh,
          ),
          const SizedBox(height: StackCardSpacing.xl),
          StackCardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StackCardInput(
                  key: const ValueKey('github_search'),
                  label: context.strings.tr('github.search'),
                  hint: context.strings.tr('github.searchHint'),
                  controller: _searchController,
                  prefixIcon: Icons.search_rounded,
                  onChanged: controller.setQuery,
                ),
                const SizedBox(height: StackCardSpacing.lg),
                Wrap(
                  spacing: StackCardSpacing.sm,
                  runSpacing: StackCardSpacing.sm,
                  children: [
                    for (final filter in GitHubRepositoryFilter.values)
                      ChoiceChip(
                        label: Text(
                          context.strings.tr('github.filter.${filter.name}'),
                        ),
                        selected: state.filter == filter,
                        onSelected: (_) => controller.setFilter(filter),
                        selectedColor: context.colors.accentSoft,
                        backgroundColor: context.colors.surface,
                        checkmarkColor: context.colors.textPrimary,
                        side: BorderSide(
                          color: state.filter == filter
                              ? context.colors.accent
                              : context.colors.textSecondary,
                        ),
                        labelStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: context.colors.textPrimary),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Semantics(
            liveRegion: true,
            child: Text(
              context.strings.tr('github.counts', {
                'visible': state.visibleRepositories.length,
                'loaded': state.repositories.length,
              }),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            context.strings.tr('github.searchScope'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: pageTextColor),
          ),
          const SizedBox(height: StackCardSpacing.lg),
        ] else if (!state.loading && state.failure == null)
          StackCardStateView(
            kind: StackCardViewState.empty,
            title: context.strings.tr('github.emptyUsername'),
            message: context.strings.tr('github.emptyUsernameHint'),
          ),
      ],
    );
  }

  Widget _footer(GitHubImportState state) {
    if (state.profile == null) return const SizedBox.shrink();
    final controller = ref.read(githubImportControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.visibleRepositories.isEmpty) ...[
          StackCardStateView(
            kind: StackCardViewState.empty,
            title: context.strings.tr(
              state.repositories.isEmpty
                  ? 'github.emptyRepos'
                  : 'github.emptySearch',
            ),
            message: context.strings.tr(
              state.repositories.isEmpty
                  ? 'github.emptyReposHint'
                  : 'github.emptySearchHint',
            ),
          ),
          if (state.query.isNotEmpty ||
              state.filter != GitHubRepositoryFilter.all)
            StackCardButton(
              label: context.strings.tr('github.reset'),
              onPressed: () {
                _searchController.clear();
                controller.resetFilters();
              },
            ),
        ],
        if (state.pageFailure case final failure?)
          GitHubFailureView(failure: failure, onRetry: controller.loadMore),
        if (state.nextPage != null && state.pageFailure == null)
          StackCardButton(
            label: context.strings.tr('github.more'),
            icon: Icons.expand_more_rounded,
            loading: state.loadingMore,
            onPressed: state.refreshing || state.loading
                ? null
                : controller.loadMore,
          ),
        const SizedBox(height: StackCardSpacing.xl),
      ],
    );
  }
}
