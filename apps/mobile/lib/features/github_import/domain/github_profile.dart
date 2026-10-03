/// Публичный профиль источника; не изменяет профиль портфолио.
final class GitHubProfile {
  const GitHubProfile({
    required this.id,
    required this.login,
    required this.htmlUrl,
    required this.publicRepositories,
    this.name,
    this.bio,
    this.location,
    this.avatarUrl,
  });

  final int id;
  final String login;
  final String htmlUrl;
  final int publicRepositories;
  final String? name;
  final String? bio;
  final String? location;
  final String? avatarUrl;
}
