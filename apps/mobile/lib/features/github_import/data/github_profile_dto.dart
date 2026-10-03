import '../domain/github_filters.dart';
import '../domain/github_profile.dart';
import 'github_json.dart';

final class GitHubProfileDto {
  const GitHubProfileDto(this.profile);

  factory GitHubProfileDto.fromJson(Object? value) {
    final json = githubObject(value);
    final login = githubString(json, 'login');
    if (login != login.trim() || validateGitHubUsername(login) != null) {
      throw const FormatException('Некорректный login');
    }
    final avatar = githubOptionalString(json, 'avatar_url');
    if (avatar != null) githubUrl(json, 'avatar_url');
    return GitHubProfileDto(
      GitHubProfile(
        id: githubInteger(json, 'id', minimum: 1),
        login: login,
        name: githubOptionalString(json, 'name'),
        bio: githubOptionalString(json, 'bio'),
        location: githubOptionalString(json, 'location'),
        htmlUrl: githubUrl(json, 'html_url'),
        avatarUrl: avatar,
        publicRepositories: githubInteger(json, 'public_repos'),
      ),
    );
  }

  final GitHubProfile profile;

  Map<String, Object?> toJson() => {
    'id': profile.id,
    'login': profile.login,
    'name': profile.name,
    'bio': profile.bio,
    'location': profile.location,
    'html_url': profile.htmlUrl,
    'avatar_url': profile.avatarUrl,
    'public_repos': profile.publicRepositories,
  };
}
