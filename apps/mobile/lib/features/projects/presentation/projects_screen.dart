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
import '../../media/media.dart';
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
    final content = ref.watch(portfolioWorkingContentProvider);
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
              : StackCardSpacing.cardPadding,
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
                        onPressed: () => context.push('/projects/new'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: StackCardSpacing.lg),
                StackCardInput(
                  key: const ValueKey('project_search'),
                  label: context.strings.tr('projects.search'),
                  hint: context.strings.tr('projects.search'),
                  showLabel: false,
                  controller: _searchController,
                  prefixIconWidget: const StackCardIcon(
                    name: 'search',
                    size: 24,
                  ),
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
                          for (final project in projects) ...[
                            _ProjectCard(
                              project: project,
                              libraryProject: _libraryProject(
                                content,
                                project.id,
                              ),
                            ),
                            const SizedBox(height: StackCardSpacing.lg),
                          ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

PortfolioProject? _libraryProject(PortfolioContent? content, String? id) {
  if (content == null || id == null) return null;
  for (final project in content.projects) {
    if (project.id == id) return project;
  }
  return null;
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, this.libraryProject});
  final Project project;
  final PortfolioProject? libraryProject;

  @override
  Widget build(BuildContext context) => ProjectLibraryCard(
    key: ValueKey('projects.card.${project.id ?? project.title}'),
    openKey: ValueKey('project_preview_${project.id ?? project.title}'),
    title: project.title,
    description: project.description,
    technologies: project.technologies,
    sourceLabel: libraryProject?.githubMetadata?.acceptedSource == null
        ? project.source.labelFor(context)
        : 'GitHub · ${libraryProject!.githubMetadata!.acceptedSource.fullName}',
    imagePaths: project.imagePaths,
    updatedAt: libraryProject?.updatedAt,
    liveUrl: libraryProject?.liveUrl ?? '',
    onOpen: project.id == null
        ? () => _showProjectDetails(context, project)
        : () => context.push(
            '/projects/${Uri.encodeComponent(project.id!)}/edit',
          ),
    onShowTechnologies: () => _showProjectDetails(context, project),
  );
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

class _ProjectImage extends StatelessWidget {
  const _ProjectImage({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) => project.imagePaths.isEmpty
      ? const _ProjectImagePlaceholder()
      : PortfolioMediaImage(
          path: project.imagePaths.first,
          width: 72,
          height: 72,
          fallback: const _ProjectImagePlaceholder(),
        );
}

class _ProjectTechnologyList extends StatelessWidget {
  const _ProjectTechnologyList({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final shown = project.technologies;
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
                      _ProjectImage(project: project),
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
                  if (project.imagePaths.isNotEmpty) ...[
                    Wrap(
                      spacing: StackCardSpacing.sm,
                      runSpacing: StackCardSpacing.sm,
                      children: [
                        for (final path in project.imagePaths)
                          PortfolioMediaImage(path: path),
                      ],
                    ),
                    const SizedBox(height: StackCardSpacing.lg),
                  ],
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
