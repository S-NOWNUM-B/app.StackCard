import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/project.dart';
import '../domain/project_filters.dart';

extension ProjectFilterLabel on ProjectFilter {
  String get label => switch (this) {
    ProjectFilter.all => 'Все',
    ProjectFilter.featured => 'Featured',
    ProjectFilter.github => 'GitHub',
    ProjectFilter.manual => 'Вручную',
  };
}

extension ProjectSourceLabel on ProjectSource {
  String get label => switch (this) {
    ProjectSource.github => 'GitHub',
    ProjectSource.manual => 'Вручную',
  };
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
