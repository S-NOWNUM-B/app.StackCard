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
    final pageTextColor = Theme.of(context).brightness == Brightness.light
        ? context.colors.textPrimary
        : context.colors.textSecondary;
    final filters = ref.watch(projectFiltersProvider);
    final projectsState = ref.watch(visibleProjectsProvider);
    final hasDraft = ref.watch(portfolioWorkingContentProvider) != null;
    final hasGitHub =
        ref
            .watch(portfolioWorkingContentProvider)
            ?.projects
            .any(
              (project) => project.source == PortfolioProjectSource.github,
            ) ==
        true;
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
                  Text(
                    context.strings.tr('projects.title'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(
                    context.strings.tr(
                      hasDraft
                          ? hasGitHub
                                ? 'githubSync.projectsSubtitle'
                                : 'builderIntegration.projectsSubtitle'
                          : 'projects.subtitle',
                    ),
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: pageTextColor),
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
                  StackCardCard(
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
                                selectedColor: context.colors.accentSoft,
                                backgroundColor: context.colors.surface,
                                checkmarkColor: context.colors.textPrimary,
                                side: BorderSide(
                                  color: filters.filter == filter
                                      ? context.colors.accent
                                      : context.colors.textSecondary,
                                ),
                                labelStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: context.colors.textPrimary,
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
                          runSpacing: StackCardSpacing.lg,
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
                  const SizedBox(height: StackCardSpacing.xl),
                  Text(
                    context.strings.tr(
                      hasDraft
                          ? 'builderIntegration.localNote'
                          : 'projects.demoNote',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: pageTextColor),
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
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProjectCover(project: project),
          const SizedBox(height: StackCardSpacing.lg),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: StackCardSpacing.sm,
            runSpacing: StackCardSpacing.sm,
            children: [
              Text(
                project.source.labelFor(context),
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: context.colors.textSecondary),
              ),
              if (project.featured)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StackCardSpacing.sm,
                    vertical: StackCardSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(StackCardRadius.small),
                  ),
                  child: Text(
                    context.strings.tr('filter.featured'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              if (!project.visible)
                Text(context.strings.tr('builderIntegration.hidden')),
            ],
          ),
          const SizedBox(height: StackCardSpacing.md),
          Text(project.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            project.description,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Wrap(
            spacing: StackCardSpacing.sm,
            runSpacing: StackCardSpacing.sm,
            children: [
              for (final technology in project.technologies)
                _TechnologyTag(label: technology),
            ],
          ),
          const SizedBox(height: StackCardSpacing.xl),
          StackCardButton(
            label: context.strings.tr('projects.view', {
              'title': project.title,
            }),
            icon: Icons.arrow_outward_rounded,
            onPressed: () => _showProjectDetails(context, project),
          ),
          if (project.id != null) ...[
            const SizedBox(height: StackCardSpacing.sm),
            StackCardButton(
              label: context.strings.tr('builderIntegration.editProject'),
              icon: Icons.edit_outlined,
              onPressed: () => context.push(
                '/projects/${Uri.encodeComponent(project.id!)}/edit',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectCover extends StatelessWidget {
  const _ProjectCover({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StackCardSpacing.xl),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(StackCardRadius.large),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.category.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.colors.textSecondary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                project.symbol,
                style:
                    (project.id == null
                            ? Theme.of(context).textTheme.displayMedium
                            : Theme.of(context).textTheme.headlineSmall)
                        ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: StackCardSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 6,
                      decoration: BoxDecoration(
                        color: context.colors.border,
                        borderRadius: BorderRadius.circular(
                          StackCardRadius.small,
                        ),
                      ),
                    ),
                    const SizedBox(height: StackCardSpacing.sm),
                    FractionallySizedBox(
                      widthFactor: 0.65,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: context.colors.border,
                          borderRadius: BorderRadius.circular(
                            StackCardRadius.small,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: StackCardSpacing.lg),
              Icon(
                project.category == 'Web tool'
                    ? Icons.terminal_rounded
                    : Icons.widgets_outlined,
                color: context.colors.textSecondary,
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Text(
            context.strings.tr(
              project.id == null
                  ? 'projects.demoCase'
                  : project.source == ProjectSource.github
                  ? 'githubSync.githubCase'
                  : 'builderIntegration.manualCase',
            ),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TechnologyTag extends StatelessWidget {
  const _TechnologyTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StackCardSpacing.sm,
        vertical: StackCardSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(StackCardRadius.small),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
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
            const SizedBox(height: StackCardSpacing.xl),
            Text(
              project.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: StackCardSpacing.sm),
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
            const SizedBox(height: StackCardSpacing.xl),
            Wrap(
              spacing: StackCardSpacing.sm,
              runSpacing: StackCardSpacing.sm,
              children: [
                for (final technology in project.technologies)
                  _TechnologyTag(label: technology),
              ],
            ),
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
