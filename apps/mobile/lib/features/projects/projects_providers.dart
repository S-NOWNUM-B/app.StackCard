import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/mock_projects_repository.dart';
import 'domain/project.dart';
import 'domain/project_filters.dart';
import 'domain/projects_repository.dart';
import 'presentation/project_filters.dart';

/// Composition feature: widgets зависят от контракта, реализация заменяется в DI.
final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => const MockProjectsRepository(),
);

final projectsProvider = FutureProvider<List<Project>>((ref) async {
  final repository = ref.watch(projectsRepositoryProvider);
  return List.unmodifiable(await repository.getProjects());
}, retry: (_, _) => null);

final visibleProjectsProvider = Provider<AsyncValue<List<Project>>>((ref) {
  final filters = ref.watch(projectFiltersProvider);
  return ref.watch(projectsProvider).whenData(filters.apply);
});

/// Featured использует полный список, независимо от поиска на Projects.
final featuredProjectsProvider = Provider<AsyncValue<List<Project>>>((ref) {
  return ref.watch(projectsProvider).whenData(selectFeaturedProjects);
});
