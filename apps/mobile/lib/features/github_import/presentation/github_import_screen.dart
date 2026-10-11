import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../../portfolio_draft/portfolio_draft.dart';
import '../../projects/projects.dart';
import '../domain/github_repository.dart';
import '../github_portfolio_providers.dart';
import 'github_cache_notice.dart';
import 'github_failure_view.dart';
import 'github_import_controller.dart';

class GitHubImportScreen extends ConsumerStatefulWidget {
  const GitHubImportScreen({super.key});

  @override
  ConsumerState<GitHubImportScreen> createState() => _GitHubImportScreenState();
}

class _GitHubImportScreenState extends ConsumerState<GitHubImportScreen> {
  final _searchController = TextEditingController();
  final _selectedIds = <int>{};
  PortfolioDraftRepository? _ownerRepository;
  String? _loadedSource;
  bool _sourceScheduled = false;
  bool _importing = false;
  bool _saveFailed = false;
  int _operationGeneration = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _synchronizeSource(
    PortfolioDraftRepository repository,
    String username,
  ) {
    if (_sourceScheduled ||
        (identical(_ownerRepository, repository) &&
            _loadedSource == username)) {
      return;
    }
    _sourceScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sourceScheduled = false;
      if (!mounted) return;
      final latest = ref.read(githubPortfolioDraftStateProvider);
      if (latest?.loaded != true) return;
      final latestRepository = ref.read(portfolioDraftRepositoryProvider);
      final latestUsername = latest?.draft?.content?.githubUsername ?? '';
      setState(() {
        _operationGeneration++;
        _importing = false;
        _ownerRepository = latestRepository;
        _loadedSource = latestUsername;
        _selectedIds.clear();
        _searchController.clear();
        _saveFailed = false;
      });
      final controller = ref.read(githubImportControllerProvider.notifier);
      controller.clear();
      if (latestUsername.isNotEmpty) controller.load(latestUsername);
    });
  }

  Future<void> _import() async {
    final repository = ref.read(portfolioDraftRepositoryProvider);
    final workspace = ref.read(githubPortfolioDraftStateProvider);
    final source = workspace?.draft?.content?.githubUsername ?? '';
    if (_importing ||
        workspace?.canEdit != true ||
        workspace!.saving ||
        !identical(repository, _ownerRepository) ||
        source != _loadedSource) {
      return;
    }
    final state = ref.read(githubImportControllerProvider);
    if (state.username != source || state.loading || state.refreshing) return;
    final imported =
        workspace.draft?.content?.projects
            .map((project) => project.githubRepositoryId)
            .whereType<int>()
            .toSet() ??
        <int>{};
    final selected = state.repositories
        .where(
          (item) =>
              _selectedIds.contains(item.id) && !imported.contains(item.id),
        )
        .toList();
    if (selected.isEmpty) return;
    final generation = ++_operationGeneration;
    setState(() {
      _importing = true;
      _saveFailed = false;
    });
    final saved = await ref
        .read(portfolioDraftControllerProvider.notifier)
        .importSelectedGitHubRepositories(
          selected.map(githubPortfolioSource).toList(),
          validatedAt: {
            for (final item in selected)
              if (state.repositoryReadMetadata[item.id]?.validatedAt
                  case final DateTime date)
                item.id: date,
          },
          expectedRepository: repository,
        );
    if (!mounted || generation != _operationGeneration) return;
    setState(() {
      _importing = false;
      if (identical(repository, ref.read(portfolioDraftRepositoryProvider)) &&
          source ==
              ref
                  .read(githubPortfolioDraftStateProvider)
                  ?.draft
                  ?.content
                  ?.githubUsername) {
        _saveFailed = !saved;
        if (saved) _selectedIds.removeAll(selected.map((item) => item.id));
      }
    });
    if (saved &&
        identical(repository, ref.read(portfolioDraftRepositoryProvider))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проекты сохранены в библиотеке')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(githubPortfolioDraftStateProvider);
    final repository = ref.watch(portfolioDraftRepositoryProvider);
    final state = ref.watch(githubImportControllerProvider);
    final controller = ref.read(githubImportControllerProvider.notifier);
    final source = workspace?.draft?.content?.githubUsername ?? '';
    if (workspace?.loaded == true) _synchronizeSource(repository, source);
    final ownerReady =
        identical(repository, _ownerRepository) && _loadedSource == source;
    final imported =
        workspace?.draft?.content?.projects
            .map((project) => project.githubRepositoryId)
            .whereType<int>()
            .toSet() ??
        <int>{};
    final busy = _importing || workspace?.saving == true;
    final canSelect =
        ownerReady && !busy && !state.loading && !state.refreshing;
    final loadedIds = state.repositories.map((item) => item.id).toSet();
    final selectedCount = ownerReady
        ? _selectedIds
              .where((id) => loadedIds.contains(id) && !imported.contains(id))
              .length
        : 0;
    ref.listen(githubImportControllerProvider.select((value) => value.query), (
      _,
      query,
    ) {
      if (_searchController.text != query) {
        _searchController.value = TextEditingValue(
          text: query,
          selection: TextSelection.collapsed(offset: query.length),
        );
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Импортировать из GitHub'),
        leading: IconButton(
          tooltip: context.strings.tr('github.back'),
          icon: const StackCardIcon(name: 'arrow-left', size: 24),
          onPressed: busy
              ? null
              : () =>
                    context.canPop() ? context.pop() : context.go('/projects'),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: StackCardSize.contentMaxWidth,
            ),
            child: workspace == null
                ? Center(
                    child: StackCardButton(
                      label: 'Войти',
                      onPressed: () =>
                          context.go('/sign-in?from=%2Fgithub-import'),
                    ),
                  )
                : !workspace.loaded
                ? StackCardStateView(
                    kind: workspace.loading
                        ? StackCardViewState.loading
                        : StackCardViewState.error,
                    title: context.strings.tr(
                      workspace.loading ? 'draft.loading' : 'draft.readFailure',
                    ),
                    onRetry: ref
                        .read(portfolioDraftControllerProvider.notifier)
                        .load,
                  )
                : RefreshIndicator(
                    onRefresh: source.isEmpty || !ownerReady || busy
                        ? () async {}
                        : controller.refresh,
                    child: ListView(
                      key: const PageStorageKey('github_import_list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(StackCardSpacing.lg),
                      children: [
                        if (source.isEmpty) ...[
                          StackCardButton(
                            key: const ValueKey('github_source_settings'),
                            label: 'Добавить GitHub-профиль',
                            onPressed: busy
                                ? null
                                : () => context.push('/settings/github'),
                          ),
                          const SizedBox(height: StackCardSpacing.lg),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '@$source',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              TextButton(
                                key: const ValueKey('github_source_settings'),
                                onPressed: busy
                                    ? null
                                    : () => context.push('/settings/github'),
                                child: const Text('Изменить'),
                              ),
                            ],
                          ),
                          const SizedBox(height: StackCardSpacing.sm),
                        ],
                        if (_saveFailed) ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              'Не удалось сохранить. Введённые данные сохранены на экране; попробуйте ещё раз.',
                              style: TextStyle(color: context.colors.error),
                            ),
                          ),
                          const SizedBox(height: StackCardSpacing.lg),
                        ],
                        if (source.isNotEmpty && !ownerReady)
                          const Center(child: CircularProgressIndicator())
                        else if (ownerReady) ...[
                          if (state.loading)
                            StackCardStateView(
                              kind: StackCardViewState.loading,
                              title: context.strings.tr('github.loading'),
                            ),
                          if (state.failure case final failure?)
                            GitHubFailureView(
                              failure: failure,
                              onRetry: controller.retry,
                            ),
                          if (state.profile != null) ...[
                            GitHubCacheNotice(metadata: state.readMetadata),
                            StackCardInput(
                              key: const ValueKey('github_search'),
                              label: context.strings.tr('github.search'),
                              hint: 'По названию и описанию',
                              controller: _searchController,
                              enabled: !busy,
                              prefixIconWidget: const StackCardIcon(
                                name: 'search',
                                size: 24,
                              ),
                              prefixIconSize: 24,
                              textInputAction: TextInputAction.search,
                              onFieldSubmitted: (_) =>
                                  FocusScope.of(context).unfocus(),
                              onChanged: controller.setQuery,
                            ),
                            const SizedBox(height: StackCardSpacing.sm),
                            if (state.failure == null)
                              TextButton(
                                onPressed:
                                    busy || state.loading || state.refreshing
                                    ? null
                                    : controller.refresh,
                                child: Text(
                                  context.strings.tr('github.refresh'),
                                ),
                              ),
                            if (state.nextPage != null) ...[
                              Text(
                                'Поиск охватывает только загруженные страницы.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: context.colors.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: StackCardSpacing.md),
                            ],
                            if (state.visibleRepositories.isEmpty)
                              StackCardStateView(
                                kind: StackCardViewState.empty,
                                title: state.nextPage != null
                                    ? 'На загруженных страницах ничего не найдено'
                                    : state.repositories.isEmpty
                                    ? context.strings.tr('github.emptyRepos')
                                    : context.strings.tr('github.emptySearch'),
                              ),
                            for (final item in state.visibleRepositories) ...[
                              _RepositorySelectionRow(
                                key: ValueKey('github_repository_${item.id}'),
                                repository: item,
                                imported: imported.contains(item.id),
                                selected: _selectedIds.contains(item.id),
                                onChanged:
                                    !canSelect || imported.contains(item.id)
                                    ? null
                                    : (selected) => setState(() {
                                        if (selected) {
                                          _selectedIds.add(item.id);
                                        } else {
                                          _selectedIds.remove(item.id);
                                        }
                                      }),
                              ),
                              const SizedBox(height: StackCardSpacing.sm),
                            ],
                            if (state.pageFailure case final failure?)
                              GitHubFailureView(
                                failure: failure,
                                onRetry: controller.loadMore,
                              ),
                            if (state.nextPage != null &&
                                state.pageFailure == null)
                              StackCardButton(
                                label: context.strings.tr('github.more'),
                                loading: state.loadingMore,
                                onPressed:
                                    busy || state.refreshing || state.loading
                                    ? null
                                    : controller.loadMore,
                              ),
                          ],
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
      bottomNavigationBar: source.isEmpty || workspace == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  StackCardSpacing.lg,
                  StackCardSpacing.lg,
                  StackCardSpacing.lg,
                  StackCardSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Align(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: StackCardSize.contentMaxWidth,
                    ),
                    child: StackCardButton(
                      key: const ValueKey('github_import_selected'),
                      label:
                          'Импортировать${selectedCount == 0 ? '' : ' ($selectedCount)'}',
                      primary: true,
                      loading: _importing,
                      onPressed: !canSelect || selectedCount == 0
                          ? null
                          : _import,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _RepositorySelectionRow extends StatelessWidget {
  const _RepositorySelectionRow({
    super.key,
    required this.repository,
    required this.imported,
    required this.selected,
    required this.onChanged,
  });
  final GitHubRepository repository;
  final bool imported;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(StackCardRadius.medium),
      side: BorderSide(color: context.colors.border),
    ),
    child: InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!selected),
      borderRadius: BorderRadius.circular(StackCardRadius.medium),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: StackCardSpacing.md,
          horizontal: StackCardSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: imported || selected,
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged!(value ?? false),
              semanticLabel: imported
                  ? '${repository.name}, уже импортирован'
                  : repository.name,
            ),
            const Padding(
              padding: EdgeInsets.only(top: StackCardSpacing.sm),
              child: ProjectStockIcon(size: 24),
            ),
            const SizedBox(width: StackCardSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    repository.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (repository.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: StackCardSpacing.xs),
                    Text(
                      repository.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: context.colors.textSecondary),
                    ),
                  ],
                  if (imported) ...[
                    const SizedBox(height: StackCardSpacing.xs),
                    const Text('Уже импортирован'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
