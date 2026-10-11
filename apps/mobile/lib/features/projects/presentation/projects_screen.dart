import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_dialog_actions.dart';
import '../../../shared/widgets/stackcard_async_view.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../../portfolio_draft/portfolio_draft.dart';
import '../domain/project.dart';
import '../domain/project_filters.dart';
import '../projects_providers.dart';
import 'project_filters.dart';
import 'project_library_card.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  late final TextEditingController _searchController;
  bool _confirmingDelete = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(projectFiltersProvider).query,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _delete(PortfolioProject project) async {
    final state = ref.read(portfolioDraftControllerProvider);
    if (_confirmingDelete || !state.canEdit || state.saving) return;
    final repository = ref.read(portfolioDraftRepositoryProvider);
    _confirmingDelete = true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Удалить проект?'),
        content: const Text(
          'Проект будет удалён из StackCard и портфолио. Репозиторий GitHub останется. '
          'Если проект опубликован, обновите публичную версию портфолио.',
        ),
        actions: [
          StackCardDialogActions(
            confirmKey: const ValueKey('project.delete.confirm'),
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    _confirmingDelete = false;
    if (accepted != true ||
        !mounted ||
        !identical(repository, ref.read(portfolioDraftRepositoryProvider))) {
      return;
    }
    final removed = await ref
        .read(portfolioDraftControllerProvider.notifier)
        .deleteProject(project, expectedRepository: repository);
    if (!mounted ||
        !identical(repository, ref.read(portfolioDraftRepositoryProvider))) {
      return;
    }
    if (!removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.tr('workspace.failure'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(projectFiltersProvider);
    final state = ref.watch(portfolioDraftControllerProvider);
    final projectsState = ref
        .watch(projectsProvider)
        .whenData(
          (projects) => ProjectFilters(query: filters.query).apply(projects),
        );
    ref.listen(projectFiltersProvider.select((filters) => filters.query), (
      previous,
      query,
    ) {
      if (_searchController.text != query) {
        _searchController.value = TextEditingValue(
          text: query,
          selection: TextSelection.collapsed(offset: query.length),
        );
      }
    });
    final importButton = StackCardButton(
      label: context.strings.tr('project.importGitHub'),
      onPressed: state.saving ? null : () => context.push('/github-import'),
    );
    final createButton = StackCardButton(
      label: context.strings.tr('project.create'),
      primary: true,
      onPressed: state.saving ? null : () => context.push('/projects/new'),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(StackCardSpacing.lg),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: StackCardSize.contentMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxWidth >= 360 &&
                        MediaQuery.textScalerOf(context).scale(1) <= 1.3
                    ? Row(
                        children: [
                          Expanded(child: importButton),
                          const SizedBox(width: StackCardSpacing.sm),
                          Expanded(child: createButton),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          importButton,
                          const SizedBox(height: StackCardSpacing.sm),
                          createButton,
                        ],
                      ),
              ),
              const SizedBox(height: StackCardSpacing.lg),
              StackCardInput(
                key: const ValueKey('project_search'),
                label: context.strings.tr('projects.search'),
                hint: context.strings.tr('projects.search'),
                showLabel: false,
                controller: _searchController,
                prefixIconWidget: const StackCardIcon(name: 'search', size: 24),
                prefixIconSize: 24,
                textInputAction: TextInputAction.search,
                onChanged: (value) =>
                    ref.read(projectFiltersProvider.notifier).setQuery(value),
              ),
              const SizedBox(height: StackCardSpacing.lg),
              StackCardAsyncView<List<Project>>(
                state: projectsState,
                onRetry: () {
                  ref.read(portfolioDraftControllerProvider.notifier).load();
                  ref.invalidate(projectsProvider);
                },
                data: (projects) => Semantics(
                  container: true,
                  explicitChildNodes: true,
                  liveRegion: true,
                  label: context.strings.tr('projects.count', {
                    'count': projects.length,
                  }),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (projects.isEmpty) ...[
                        StackCardStateView(
                          kind: filters.query.trim().isEmpty
                              ? StackCardViewState.empty
                              : StackCardViewState.noResults,
                          title: filters.query.trim().isEmpty
                              ? 'Проектов пока нет'
                              : context.strings.tr('project.noResultsTitle'),
                        ),
                      ] else
                        for (final project in projects) ...[
                          ProjectLibraryCard(
                            key: ValueKey(
                              'projects.card.${project.id ?? project.title}',
                            ),
                            openKey: ValueKey(
                              'project_preview_${project.id ?? project.title}',
                            ),
                            title: project.title,
                            description: project.description,
                            iconId: project.iconId,
                            onEdit: project.id == null || state.saving
                                ? null
                                : () => context.push(
                                    '/projects/${Uri.encodeComponent(project.id!)}/edit',
                                  ),
                            onDelete:
                                state.saving ||
                                    state.content == null ||
                                    project.id == null ||
                                    !state.content!.projects.any(
                                      (item) => item.id == project.id,
                                    )
                                ? null
                                : () => _delete(
                                    state.content!.projects.firstWhere(
                                      (item) => item.id == project.id,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: StackCardSpacing.sm),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
