import 'package:app_stackcard/features/projects/data/mock_projects_repository.dart';
import 'package:app_stackcard/features/projects/domain/project.dart';
import 'package:app_stackcard/features/projects/domain/project_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Mock preserves the four cases, sources and curated featured selection',
    () async {
      final projects = await const MockProjectsRepository().getProjects();

      expect(projects.map((project) => project.title), [
        'Atlas UI Kit',
        'Pocket Tasks',
        'Readme Studio',
        'Weather Notes',
      ]);
      expect(projects.map((project) => project.source), [
        ProjectSource.github,
        ProjectSource.manual,
        ProjectSource.github,
        ProjectSource.manual,
      ]);
      expect(selectFeaturedProjects(projects).map((project) => project.title), [
        'Atlas UI Kit',
        'Pocket Tasks',
      ]);
      expect(projects[2].technologies, ['React', 'TypeScript']);
      expect(() => projects.clear(), throwsUnsupportedError);
      expect(() => projects.first.technologies.clear(), throwsUnsupportedError);
      expect(
        () => selectFeaturedProjects(projects).clear(),
        throwsUnsupportedError,
      );
    },
  );

  test('Project defensively owns its technologies and typed source', () {
    final technologies = ['Dart'];
    final project = Project(
      title: 'A project',
      description: 'Description',
      technologies: technologies,
      symbol: 'A',
      category: 'Mobile app',
      source: ProjectSource.manual,
      featured: true,
      details: 'Details',
    );

    technologies.add('Unrelated');

    expect(project.technologies, ['Dart']);
    expect(project.isFromGitHub, isFalse);
    expect(() => project.technologies.add('Flutter'), throwsUnsupportedError);
  });

  test('Pure search and filters exclude source, category and details text', () {
    final project = Project(
      title: 'A project',
      description: 'Description',
      technologies: ['Dart'],
      symbol: 'A',
      category: 'Unique category',
      source: ProjectSource.github,
      featured: false,
      details: 'Unique details',
    );

    expect(const ProjectFilters(query: ' DART ').apply([project]), [project]);
    expect(const ProjectFilters(query: 'Unique').apply([project]), isEmpty);
    expect(const ProjectFilters(query: 'GitHub').apply([project]), isEmpty);
    expect(
      const ProjectFilters(filter: ProjectFilter.manual).apply([project]),
      isEmpty,
    );
    expect(
      const ProjectFilters(filter: ProjectFilter.github).apply([project]),
      [project],
    );
    expect(
      () => const ProjectFilters().apply([project]).clear(),
      throwsUnsupportedError,
    );
  });
}
