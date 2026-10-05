import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_async_view.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../../../shared/widgets/stackcard_technology_badge.dart';
import '../../portfolio_draft/portfolio_draft.dart';
import '../domain/project.dart';
import '../domain/project_filters.dart';
import '../projects_providers.dart';
import 'project_filters.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  late final TextEditingController _searchController;

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

  void _clearSearch() {
    ref.read(projectFiltersProvider.notifier).setQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(projectFiltersProvider);
    final projectsState = ref
        .watch(projectsProvider)
        .whenData(
          (projects) => ProjectFilters(query: filters.query).apply(projects),
        );
    final suggestions = ref.watch(portfolioSuggestionsProvider);
    final draftState = ref.watch(portfolioDraftControllerProvider);
    final hasDraft = ref.watch(portfolioWorkingContentProvider) != null;
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

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.all(
          constraints.maxWidth >= 700
              ? StackCardSpacing.xl
              : StackCardSpacing.lg,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: StackCardSize.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: StackCardButton(
                        label: context.strings.tr('project.importGitHub'),
                        onPressed: () => context.push('/github-import'),
                      ),
                    ),
                    const SizedBox(width: StackCardSpacing.sm),
                    Expanded(
                      child: StackCardButton(
                        label: context.strings.tr('project.create'),
                        primary: true,
                        iconWidget: const StackCardIcon(name: 'plus', size: 18),
                        onPressed: () => context.push('/projects/new'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: StackCardSpacing.lg),
                StackCardInput(
                  key: const ValueKey('project_search'),
                  label: context.strings.tr('projects.search'),
                  hint: context.strings.tr('projects.searchHint'),
                  showLabel: false,
                  controller: _searchController,
                  prefixIconWidget: const StackCardIcon(
                    name: 'search',
                    size: 20,
                  ),
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
                  data: (projects) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          context.strings.tr('projects.count', {
                            'count': projects.length,
                          }),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.colors.textMeta),
                        ),
                      ),
                      const SizedBox(height: StackCardSpacing.sm),
                      if (projects.isEmpty)
                        StackCardCard(
                          child: Column(
                            children: [
                              StackCardStateView(
                                kind: filters.query.trim().isEmpty
                                    ? StackCardViewState.empty
                                    : StackCardViewState.noResults,
                                title: context.strings.tr(
                                  filters.query.trim().isEmpty
                                      ? 'project.emptyTitle'
                                      : 'project.noResultsTitle',
                                ),
                                message: context.strings.tr(
                                  filters.query.trim().isEmpty
                                      ? 'project.emptyMessage'
                                      : 'project.noResultsMessage',
                                ),
                              ),
                              if (filters.query.trim().isNotEmpty)
                                StackCardButton(
                                  label: context.strings.tr(
                                    'project.clearSearch',
                                  ),
                                  onPressed: _clearSearch,
                                ),
                            ],
                          ),
                        )
                      else
                        for (final project in projects)
                          _ProjectCard(project: project),
                    ],
                  ),
                ),
                if (hasDraft) ...[
                  const SizedBox(height: StackCardSpacing.xl),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StackCardButton(
                      label: context.strings.tr('githubSync.openBuilder'),
                      iconWidget: const StackCardIcon(
                        name: 'panels-top-left',
                        size: 18,
                      ),
                      onPressed: () => context.push('/portfolio/builder'),
                    ),
                  ),
                ],
                if (suggestions.isNotEmpty &&
                    draftState.canEdit &&
                    !draftState.saving) ...[
                  const SizedBox(height: StackCardSpacing.xl),
                  PortfolioSuggestionList(
                    key: const ValueKey('projects_suggestions'),
                    suggestions: suggestions,
                    onAction: (suggestion) {
                      final id = suggestion.projectId;
                      if (id != null) {
                        context.push(
                          '/projects/${Uri.encodeComponent(id)}/edit',
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final metadata = [
      if (project.featured) context.strings.tr('filter.featured'),
      if (!project.visible) context.strings.tr('builderIntegration.hidden'),
    ].join(' · ');
    return StackCardCard(
      padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ProjectImagePlaceholder(),
              const SizedBox(width: StackCardSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: StackCardSpacing.xs),
                    Text(
                      project.source.labelFor(context),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: context.colors.sourceText),
                    ),
                    if (metadata.isNotEmpty) ...[
                      const SizedBox(height: StackCardSpacing.xs),
                      Text(
                        metadata,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: context.colors.textMeta),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (project.description.isNotEmpty) ...[
            const SizedBox(height: StackCardSpacing.md),
            Text(
              project.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.colors.textSecondary),
            ),
          ],
          if (project.technologies.isNotEmpty) ...[
            const SizedBox(height: StackCardSpacing.md),
            _ProjectTechnologyList(project: project, compact: true),
          ],
          const SizedBox(height: StackCardSpacing.md),
          Wrap(
            spacing: StackCardSpacing.sm,
            runSpacing: StackCardSpacing.sm,
            children: [
              StackCardButton(
                key: ValueKey('project_preview_${project.id ?? project.title}'),
                label: context.strings.tr('githubSync.preview'),
                iconWidget: const StackCardIcon(
                  name: 'panels-top-left',
                  size: 18,
                ),
                onPressed: () => _showProjectDetails(context, project),
              ),
              if (project.id != null)
                StackCardButton(
                  label: context.strings.tr('builderIntegration.edit'),
                  iconWidget: const StackCardIcon(name: 'pencil', size: 18),
                  onPressed: () => context.push(
                    '/projects/${Uri.encodeComponent(project.id!)}/edit',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectImagePlaceholder extends StatelessWidget {
  const _ProjectImagePlaceholder();

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.strings.tr('project.noImage'),
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: 72,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surfaceElevated,
            border: Border.all(color: context.colors.borderStrong),
            borderRadius: BorderRadius.circular(StackCardRadius.small),
          ),
          child: Center(
            child: StackCardIcon(
              name: 'image',
              size: 28,
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ),
    ),
  );
}

class _ProjectTechnologyList extends StatelessWidget {
  const _ProjectTechnologyList({required this.project, this.compact = false});

  final Project project;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final shown = compact ? project.technologies.take(4) : project.technologies;
    final remaining = project.technologies.length - shown.length;
    return Wrap(
      spacing: StackCardSpacing.sm,
      runSpacing: StackCardSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final technology in shown)
          StackCardTechnologyBadge(label: technology),
        if (remaining > 0)
          StackCardMoreTechnologies(
            count: remaining,
            label: context.strings.tr('project.moreTechnologies', {
              'count': remaining,
            }),
            onPressed: () => _showProjectDetails(context, project),
          ),
      ],
    );
  }
}

void _showProjectDetails(BuildContext context, Project project) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: StackCardSize.contentMaxWidth),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                StackCardSpacing.lg,
                StackCardSpacing.sm,
                StackCardSpacing.lg,
                StackCardSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _ProjectImagePlaceholder(),
                      const SizedBox(width: StackCardSpacing.md),
                      Expanded(
                        child: Text(
                          project.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                  Text(
                    context.strings.tr(
                      project.id == null
                          ? 'projects.sourceNote'
                          : 'githubSync.sourceNote',
                      {'source': project.source.labelFor(context)},
                    ),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.colors.textMeta),
                  ),
                  const SizedBox(height: StackCardSpacing.xl),
                  SelectableText(
                    project.details,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (project.technologies.isNotEmpty) ...[
                    const SizedBox(height: StackCardSpacing.xl),
                    _ProjectTechnologyList(project: project),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(StackCardSpacing.lg),
              child: StackCardButton(
                label: context.strings.tr('projects.close'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
