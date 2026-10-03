import 'github_repository.dart';

String normalizeGitHubUsername(String value) => value.trim().toLowerCase();

String? validateGitHubUsername(String? value) {
  final username = normalizeGitHubUsername(value ?? '');
  if (username.isEmpty) return 'Введи username GitHub';
  if (username.length > 39 ||
      !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(username)) {
    return 'Используй до 39 букв, цифр и одиночных дефисов';
  }
  return null;
}

enum GitHubRepositoryFilter { all, originals, forks, archived }

/// Поиск применяется только к загруженным страницам, без Search API.
List<GitHubRepository> filterGitHubRepositories(
  Iterable<GitHubRepository> repositories, {
  String query = '',
  GitHubRepositoryFilter filter = GitHubRepositoryFilter.all,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  return List.unmodifiable(
    repositories.where((repository) {
      final matchesFilter = switch (filter) {
        GitHubRepositoryFilter.all => true,
        GitHubRepositoryFilter.originals => !repository.isFork,
        GitHubRepositoryFilter.forks => repository.isFork,
        GitHubRepositoryFilter.archived => repository.archived,
      };
      final searchText =
          '${repository.name} ${repository.description ?? ''} '
                  '${repository.language ?? ''}'
              .toLowerCase();
      return matchesFilter && searchText.contains(normalizedQuery);
    }),
  );
}
