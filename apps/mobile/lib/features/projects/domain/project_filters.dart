import 'project.dart';

enum ProjectFilter { all, featured, github, manual }

List<Project> selectFeaturedProjects(Iterable<Project> projects) =>
    List.unmodifiable(projects.where((project) => project.featured));

/// Правила отбора проектов, независимые от UI и способа загрузки данных.
final class ProjectFilters {
  const ProjectFilters({this.query = '', this.filter = ProjectFilter.all});

  final String query;
  final ProjectFilter filter;

  List<Project> apply(Iterable<Project> projects) {
    final normalizedQuery = query.trim().toLowerCase();
    return List.unmodifiable(
      projects.where((project) {
        final matchesQuery = [
          project.title,
          project.description,
          ...project.technologies,
        ].join(' ').toLowerCase().contains(normalizedQuery);
        final matchesFilter = switch (filter) {
          ProjectFilter.all => true,
          ProjectFilter.featured => project.featured,
          ProjectFilter.github => project.isFromGitHub,
          ProjectFilter.manual => !project.isFromGitHub,
        };
        return matchesQuery && matchesFilter;
      }),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectFilters && query == other.query && filter == other.filter;

  @override
  int get hashCode => Object.hash(query, filter);
}
