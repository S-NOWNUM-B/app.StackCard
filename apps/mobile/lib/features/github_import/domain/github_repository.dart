import 'github_read_metadata.dart';

/// Metadata публичного репозитория GitHub, отдельно от curated Project.
final class GitHubRepository {
  const GitHubRepository({
    required this.id,
    required this.name,
    required this.fullName,
    required this.htmlUrl,
    required this.stars,
    required this.forks,
    required this.isFork,
    required this.archived,
    required this.updatedAt,
    this.description,
    this.language,
  });

  final int id;
  final String name;
  final String fullName;
  final String htmlUrl;
  final int stars;
  final int forks;
  final bool isFork;
  final bool archived;
  final DateTime updatedAt;
  final String? description;
  final String? language;
}

final class GitHubRepositoriesPage {
  GitHubRepositoriesPage({
    required Iterable<GitHubRepository> repositories,
    this.nextPage,
    this.readMetadata = const GitHubReadMetadata(),
  }) : repositories = List.unmodifiable(repositories);

  final List<GitHubRepository> repositories;
  final Uri? nextPage;
  final GitHubReadMetadata readMetadata;
}
