import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/mock_projects_repository.dart';
import 'domain/project.dart';
import 'domain/project_filters.dart';
import 'domain/projects_repository.dart';
import 'presentation/project_filters.dart';
import '../portfolio_draft/portfolio_draft.dart';
import 'presentation/portfolio_projects_projection.dart';

/// Composition feature: widgets зависят от контракта, реализация заменяется в DI.
final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => const MockProjectsRepository(),
);

final projectsProvider = FutureProvider<List<Project>>((ref) async {
  final repository = ref.watch(projectsRepositoryProvider);
  ref.watch(portfolioDraftRepositoryProvider);
  // Подписка на readiness ставится после первого read: его завершение не
  // должно инвалидировать ожидающий Future и повторно вызывать demo source.
  try {
    await ref.read(portfolioDraftControllerProvider.notifier).ensureLoaded();
  } on PortfolioDraftFailure {
    if (ref.mounted) {
      ref.watch(
        portfolioDraftControllerProvider.select(
          (state) => (
            state.loaded,
            state.loaded ? null : state.failure,
            state.content,
          ),
        ),
      );
    }
    rethrow;
  }
  if (!ref.mounted) throw StateError('Projects read was cancelled');
  final (_, _, content) = ref.watch(
    portfolioDraftControllerProvider.select(
      (state) =>
          (state.loaded, state.loaded ? null : state.failure, state.content),
    ),
  );
  if (content != null) return projectPortfolioProjects(content);
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
