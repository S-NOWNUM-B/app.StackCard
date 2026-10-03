import 'package:flutter/material.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import '../../shared/mock_portfolio.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_card.dart';
import '../../shared/widgets/stackcard_input.dart';
import '../../shared/widgets/stackcard_states.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _searchController = TextEditingController();
  var _query = '';
  var _filter = _ProjectFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _filter = _ProjectFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pageTextColor = Theme.of(context).brightness == Brightness.light
        ? context.colors.textPrimary
        : context.colors.textSecondary;
    final query = _query.trim().toLowerCase();
    final projects = DemoPortfolio.projects.where((project) {
      final matchesQuery = [
        project.title,
        project.description,
        ...project.technologies,
      ].join(' ').toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _ProjectFilter.all => true,
        _ProjectFilter.featured => project.featured,
        _ProjectFilter.github => project.isFromGitHub,
        _ProjectFilter.manual => !project.isFromGitHub,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    return LayoutBuilder(
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
                  'Сделано тобой',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: StackCardSpacing.sm),
                Text(
                  'От pet project до большого продукта — каждой работе есть место.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: pageTextColor),
                ),
                const SizedBox(height: StackCardSpacing.xl),
                StackCardCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StackCardInput(
                        key: const ValueKey('project_search'),
                        label: 'Поиск проектов',
                        hint: 'Название или технология',
                        controller: _searchController,
                        prefixIcon: Icons.search_rounded,
                        textInputAction: TextInputAction.search,
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: StackCardSpacing.lg),
                      Wrap(
                        spacing: StackCardSpacing.sm,
                        runSpacing: StackCardSpacing.sm,
                        children: [
                          for (final filter in _ProjectFilter.values)
                            ChoiceChip(
                              label: Text(filter.label),
                              selected: _filter == filter,
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                              selectedColor: context.colors.accentSoft,
                              backgroundColor: context.colors.surface,
                              checkmarkColor: context.colors.textPrimary,
                              side: BorderSide(
                                color: _filter == filter
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
                const SizedBox(height: StackCardSpacing.xl),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Проекты: ${projects.length}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: StackCardSpacing.lg),
                if (projects.isEmpty)
                  StackCardCard(
                    child: Column(
                      children: [
                        const StackCardStateView(
                          kind: StackCardViewState.empty,
                          title: 'Ничего не найдено',
                          message: 'Попробуй другое название, технологию или сбрось фильтры.',
                        ),
                        StackCardButton(
                          label: 'Сбросить фильтры',
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
                          ? (gridConstraints.maxWidth - StackCardSpacing.lg) / 2
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
                  'Все карточки — демонстрационные. Поиск и фильтры работают '
                  'с примерами; импорт, создание и редактирование проектов '
                  'появятся на следующих этапах.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: pageTextColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ProjectFilter {
  all('Все'),
  featured('Featured'),
  github('GitHub'),
  manual('Вручную');

  const _ProjectFilter(this.label);

  final String label;
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final DemoProject project;

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
                project.source,
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
                    'Featured',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
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
            label: 'Посмотреть ${project.title}',
            icon: Icons.arrow_outward_rounded,
            onPressed: () => _showProjectDetails(context, project),
          ),
        ],
      ),
    );
  }
}

class _ProjectCover extends StatelessWidget {
  const _ProjectCover({required this.project});

  final DemoProject project;

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
                style: Theme.of(context).textTheme.displayMedium
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
            'Демонстрационный кейс',
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

void _showProjectDetails(BuildContext context, DemoProject project) {
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
              '${project.source} · демонстрационные данные',
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
              label: 'Закрыть проект',
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
