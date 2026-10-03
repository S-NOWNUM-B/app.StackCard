import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/mock_portfolio.dart';

enum ProjectFilter {
  all('Все'),
  featured('Featured'),
  github('GitHub'),
  manual('Вручную');

  const ProjectFilter(this.label);

  final String label;
}

@immutable
class ProjectFilters {
  const ProjectFilters({this.query = '', this.filter = ProjectFilter.all});

  final String query;
  final ProjectFilter filter;

  @override
  bool operator ==(Object other) =>
      other is ProjectFilters && query == other.query && filter == other.filter;

  @override
  int get hashCode => Object.hash(query, filter);
}

// Без autoDispose: выбор сохраняется между экранами внутри одной сессии.
final projectFiltersProvider =
    NotifierProvider<ProjectFiltersNotifier, ProjectFilters>(
      ProjectFiltersNotifier.new,
    );

class ProjectFiltersNotifier extends Notifier<ProjectFilters> {
  @override
  ProjectFilters build() => const ProjectFilters();

  void setQuery(String query) {
    state = ProjectFilters(query: query, filter: state.filter);
  }

  void setFilter(ProjectFilter filter) {
    state = ProjectFilters(query: state.query, filter: filter);
  }

  void reset() {
    state = const ProjectFilters();
  }
}

final visibleDemoProjectsProvider = Provider<List<DemoProject>>((ref) {
  final filters = ref.watch(projectFiltersProvider);
  final query = filters.query.trim().toLowerCase();
  return List<DemoProject>.unmodifiable(
    DemoPortfolio.projects.where((project) {
      final matchesQuery = [
        project.title,
        project.description,
        ...project.technologies,
      ].join(' ').toLowerCase().contains(query);
      final matchesFilter = switch (filters.filter) {
        ProjectFilter.all => true,
        ProjectFilter.featured => project.featured,
        ProjectFilter.github => project.isFromGitHub,
        ProjectFilter.manual => !project.isFromGitHub,
      };
      return matchesQuery && matchesFilter;
    }),
  );
});
