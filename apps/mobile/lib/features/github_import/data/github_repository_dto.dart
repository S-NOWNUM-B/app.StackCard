import '../domain/github_repository.dart';
import 'github_json.dart';

final class GitHubRepositoryDto {
  const GitHubRepositoryDto(this.repository);

  factory GitHubRepositoryDto.fromJson(Object? value) {
    final json = githubObject(value);
    final timestamp = githubString(json, 'updated_at');
    final updated = DateTime.tryParse(timestamp);
    if (updated == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$')
            .hasMatch(timestamp) ||
        updated.toUtc().toIso8601String().substring(0, 19) !=
            timestamp.substring(0, 19)) {
      throw const FormatException('Некорректная дата');
    }
    return GitHubRepositoryDto(
      GitHubRepository(
        id: githubInteger(json, 'id', minimum: 1),
        name: githubString(json, 'name'),
        fullName: githubString(json, 'full_name'),
        description: githubOptionalString(json, 'description'),
        htmlUrl: githubUrl(json, 'html_url'),
        language: githubOptionalString(json, 'language'),
        stars: githubInteger(json, 'stargazers_count'),
        forks: githubInteger(json, 'forks_count'),
        isFork: githubBoolean(json, 'fork'),
        archived: githubBoolean(json, 'archived'),
        updatedAt: updated.toUtc(),
      ),
    );
  }

  final GitHubRepository repository;

  Map<String, Object?> toJson() => {
    'id': repository.id,
    'name': repository.name,
    'full_name': repository.fullName,
    'description': repository.description,
    'html_url': repository.htmlUrl,
    'language': repository.language,
    'stargazers_count': repository.stars,
    'forks_count': repository.forks,
    'fork': repository.isFork,
    'archived': repository.archived,
    'updated_at': repository.updatedAt.toUtc().toIso8601String(),
  };
}
