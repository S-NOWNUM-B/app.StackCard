import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_async_view.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../../shared/widgets/stackcard_poster.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/project.dart';
import '../domain/project_filters.dart';
import '../projects_providers.dart';
import '../../portfolio_draft/portfolio_draft.dart';
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

  void _resetFilters() {
    ref.read(projectFiltersProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(projectFiltersProvider);
    final projectsState = ref.watch(visibleProjectsProvider);
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

    return StackCardAsyncView<List<Project>>(
      state: projectsState,
      onRetry: () {
        ref.read(portfolioDraftControllerProvider.notifier).load();
        ref.invalidate(projectsProvider);
      },
      data: (projects) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.all(
            constraints.maxWidth >= 700
                ? StackCardSpacing.xl
                : StackCardSpacing.lg,
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: StackCardPoster(
                      color: context.colors.cyan,
                      variant: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.arrow_outward_rounded,
                            color: context.colors.ink,
                            size: 40,
                          ),
                          const SizedBox(height: StackCardSpacing.xxl),
                          Text(
                            context.strings.tr('projects.title'),
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(color: context.colors.ink),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: StackCardSpacing.xl),
                  Wrap(
                    spacing: StackCardSpacing.md,
                    runSpacing: StackCardSpacing.md,
                    children: [
                      StackCardButton(
                        label: 'GitHub Import',
                        icon: Icons.download_rounded,
                        onPressed: () => context.push('/github-import'),
                      ),
                      StackCardButton(
                        label: context.strings.tr(
                          'builderIntegration.addProject',
                        ),
                        icon: Icons.add_rounded,
                        onPressed: () => context.push('/projects/new'),
                      ),
                      if (hasDraft)
                        StackCardButton(
                          label: context.strings.tr('builderIntegration.edit'),
                          icon: Icons.tune_rounded,
                          onPressed: () => context.push('/portfolio/builder'),
                        ),
                    ],
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                  if (suggestions.isNotEmpty &&
                      draftState.canEdit &&
                      !draftState.saving) ...[
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
                    const SizedBox(height: StackCardSpacing.lg),
                  ],
                  StackCardCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: StackCardSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StackCardInput(
                          key: const ValueKey('project_search'),
                          label: context.strings.tr('projects.search'),
                          hint: context.strings.tr('projects.searchHint'),
                          controller: _searchController,
                          prefixIcon: Icons.search_rounded,
                          textInputAction: TextInputAction.search,
                          onChanged: (value) => ref
                              .read(projectFiltersProvider.notifier)
                              .setQuery(value),
                        ),
                        const SizedBox(height: StackCardSpacing.lg),
                        Wrap(
                          spacing: StackCardSpacing.sm,
                          runSpacing: StackCardSpacing.sm,
                          children: [
                            for (final filter in ProjectFilter.values)
                              ChoiceChip(
                                label: Text(filter.labelFor(context)),
                                selected: filters.filter == filter,
                                onSelected: (_) => ref
                                    .read(projectFiltersProvider.notifier)
                                    .setFilter(filter),
                                showCheckmark: false,
                                selectedColor: context.colors.cyan,
                                backgroundColor: Colors.transparent,
                                side: BorderSide(
                                  color: filters.filter == filter
                                      ? context.colors.cyan
                                      : context.colors.border,
                                ),
                                labelStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: filters.filter == filter
                                          ? context.colors.ink
                                          : context.colors.textPrimary,
                                    ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: StackCardSpacing.xl),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      context.strings.tr('projects.count', {
                        'count': projects.length,
                      }),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                  if (projects.isEmpty)
                    StackCardCard(
                      child: Column(
                        children: [
                          StackCardStateView(
                            kind: StackCardViewState.empty,
                            title: context.strings.tr('projects.emptyTitle'),
                            message: context.strings.tr(
                              'projects.emptyMessage',
                            ),
                          ),
                          StackCardButton(
                            label: context.strings.tr('projects.reset'),
                            icon: Icons.refresh_rounded,
                            onPressed: _resetFilters,
                          ),
                        ],
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, gridConstraints) {
                        final twoColumns =
                            gridConstraints.maxWidth >= 700 &&
                            MediaQuery.textScalerOf(context).scale(1) < 1.7;
                        final cardWidth = twoColumns
                            ? (gridConstraints.maxWidth - StackCardSpacing.lg) /
                                  2
                            : gridConstraints.maxWidth;
                        return Wrap(
                          spacing: StackCardSpacing.lg,
                          runSpacing: StackCardSpacing.sm,
                          children: [
                            for (final project in projects)
                              SizedBox(
                                width: cardWidth,
                                child: _ProjectCard(project: project),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
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
      project.source.labelFor(context),
      if (project.featured) context.strings.tr('filter.featured'),
      if (!project.visible) context.strings.tr('builderIntegration.hidden'),
    ].join(' · ');
    return StackCardCard(
      padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: context.colors.textSecondary),
                    ),
                    const SizedBox(height: StackCardSpacing.sm),
                    Text(
                      project.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: StackCardSpacing.lg),
              ExcludeSemantics(
                child: Text(
                  project.symbol,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? project.featured
                              ? context.colors.pink
                              : context.colors.cyan
                        : context.colors.textPrimary,
                  ),
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
            const SizedBox(height: StackCardSpacing.lg),
            Text(
              project.technologies.join(' / '),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
          const SizedBox(height: StackCardSpacing.lg),
          Wrap(
            spacing: StackCardSpacing.sm,
            runSpacing: StackCardSpacing.sm,
            children: [
              StackCardButton(
                key: ValueKey('project_preview_${project.id ?? project.title}'),
                label: context.strings.tr('githubSync.preview'),
                icon: Icons.arrow_outward_rounded,
                onPressed: () => _showProjectDetails(context, project),
              ),
              if (project.id != null)
                StackCardButton(
                  label: context.strings.tr('builderIntegration.edit'),
                  icon: Icons.edit_outlined,
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

class _ProjectCover extends StatelessWidget {
  const _ProjectCover({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) => StackCardPoster(
    color: project.featured ? context.colors.pink : context.colors.cyan,
    variant: 1,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          project.category.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: context.colors.ink),
        ),
        StackCardArtwork(height: 140, color: context.colors.ink, variant: 1),
        Text(
          project.title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: context.colors.ink),
        ),
      ],
    ),
  );
}

void _showProjectDetails(BuildContext context, Project project) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.85,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          StackCardSpacing.xl,
          StackCardSpacing.sm,
          StackCardSpacing.xl,
          StackCardSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProjectCover(project: project),
            const SizedBox(height: StackCardSpacing.lg),
            Text(
              context.strings.tr(
                project.id == null
                    ? 'projects.sourceNote'
                    : 'githubSync.sourceNote',
                {'source': project.source.labelFor(context)},
              ),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: StackCardSpacing.xl),
            Text(project.details, style: Theme.of(context).textTheme.bodyLarge),
            if (project.technologies.isNotEmpty) ...[
              const SizedBox(height: StackCardSpacing.xl),
              Text(
                project.technologies.join(' / '),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
            const SizedBox(height: StackCardSpacing.xl),
            StackCardButton(
              label: context.strings.tr('projects.close'),
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
