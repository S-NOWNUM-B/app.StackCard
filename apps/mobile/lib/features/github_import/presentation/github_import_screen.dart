import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/github_filters.dart';
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.background,
        title: const Text('GitHub Import'),
        leading: IconButton(
          tooltip: 'Назад к проектам',
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
          'Найди свои репозитории',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: StackCardSpacing.sm),
        Text(
          'Просмотр публичного GitHub без входа. Данные остаются источником: '
          'портфолио и демонстрационный профиль не меняются.',
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
                  label: 'Username GitHub',
                  hint: 'Например, octocat',
                  controller: _usernameController,
                  validator: validateGitHubUsername,
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: StackCardSpacing.lg),
                StackCardButton(
                  label: 'Загрузить профиль',
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
          const StackCardStateView(
            kind: StackCardViewState.loading,
            title: 'Загрузка GitHub',
            message:
                'Получаем публичный профиль и первую страницу репозиториев.',
          ),
        if (state.failure case final failure?)
          GitHubFailureView(failure: failure, onRetry: controller.retry),
        if (state.profile case final profile?) ...[
          GitHubProfileCard(profile: profile),
          const SizedBox(height: StackCardSpacing.lg),
          StackCardButton(
            label: 'Обновить GitHub',
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
                  label: 'Поиск репозиториев',
                  hint: 'Название, описание или язык',
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
                        label: Text(switch (filter) {
                          GitHubRepositoryFilter.all => 'Все',
                          GitHubRepositoryFilter.originals => 'Оригинальные',
                          GitHubRepositoryFilter.forks => 'Forks',
                          GitHubRepositoryFilter.archived => 'Архив',
                        }),
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
              'Показано: ${state.visibleRepositories.length} · Загружено: ${state.repositories.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            'Поиск и фильтры применяются к загруженным страницам.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: pageTextColor),
          ),
          const SizedBox(height: StackCardSpacing.lg),
        ] else if (!state.loading && state.failure == null)
          const StackCardStateView(
            kind: StackCardViewState.empty,
            title: 'Введи username',
            message: 'Покажем профиль и доступные публичные репозитории.',
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
            title: state.repositories.isEmpty
                ? 'Публичных репозиториев нет'
                : 'Ничего не найдено',
            message: state.repositories.isEmpty
                ? 'Можно попробовать другой username.'
                : 'Измени поиск, сбрось фильтры или загрузи следующую страницу.',
          ),
          if (state.query.isNotEmpty ||
              state.filter != GitHubRepositoryFilter.all)
            StackCardButton(
              label: 'Сбросить поиск и фильтры',
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
            label: 'Загрузить ещё',
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
