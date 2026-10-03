import 'github_profile.dart';
import 'github_repository.dart';

abstract interface class GitHubImportRepository {
  Future<GitHubProfile> getProfile(String username);

  /// [page] берётся из ответа предыдущего запроса; null открывает первую страницу.
  Future<GitHubRepositoriesPage> getRepositories(
    GitHubProfile profile, {
    Uri? page,
  });

  /// Отменяет запросы закрытого или заменённого сценария просмотра.
  void cancelRequests();
}
