import '../domain/github_failure.dart';
import '../domain/github_filters.dart';
import '../domain/github_profile.dart';
import '../domain/github_read_metadata.dart';
import '../domain/github_repository.dart';

const _unchanged = Object();

final class GitHubImportState {
  GitHubImportState({
    this.username = '',
    this.profile,
    Iterable<GitHubRepository> repositories = const [],
    this.nextPage,
    this.loading = false,
    this.refreshing = false,
    this.loadingMore = false,
    this.failure,
    this.pageFailure,
    this.query = '',
    this.filter = GitHubRepositoryFilter.all,
    this.readMetadata = const GitHubReadMetadata(),
    Map<int, GitHubReadMetadata> repositoryReadMetadata = const {},
  }) : repositories = List.unmodifiable(repositories),
       repositoryReadMetadata = Map.unmodifiable(repositoryReadMetadata);

  final String username;
  final GitHubProfile? profile;
  final List<GitHubRepository> repositories;
  final Uri? nextPage;
  final bool loading;
  final bool refreshing;
  final bool loadingMore;
  final GitHubFailure? failure;
  final GitHubFailure? pageFailure;
  final String query;
  final GitHubRepositoryFilter filter;
  final GitHubReadMetadata readMetadata;
  final Map<int, GitHubReadMetadata> repositoryReadMetadata;

  List<GitHubRepository> get visibleRepositories =>
      filterGitHubRepositories(repositories, query: query, filter: filter);

  GitHubImportState copyWith({
    String? username,
    Object? profile = _unchanged,
    Iterable<GitHubRepository>? repositories,
    Object? nextPage = _unchanged,
    bool? loading,
    bool? refreshing,
    bool? loadingMore,
    Object? failure = _unchanged,
    Object? pageFailure = _unchanged,
    String? query,
    GitHubRepositoryFilter? filter,
    GitHubReadMetadata? readMetadata,
    Map<int, GitHubReadMetadata>? repositoryReadMetadata,
  }) => GitHubImportState(
    username: username ?? this.username,
    profile: identical(profile, _unchanged)
        ? this.profile
        : profile as GitHubProfile?,
    repositories: repositories ?? this.repositories,
    nextPage: identical(nextPage, _unchanged)
        ? this.nextPage
        : nextPage as Uri?,
    loading: loading ?? this.loading,
    refreshing: refreshing ?? this.refreshing,
    loadingMore: loadingMore ?? this.loadingMore,
    failure: identical(failure, _unchanged)
        ? this.failure
        : failure as GitHubFailure?,
    pageFailure: identical(pageFailure, _unchanged)
        ? this.pageFailure
        : pageFailure as GitHubFailure?,
    query: query ?? this.query,
    filter: filter ?? this.filter,
    readMetadata: readMetadata ?? this.readMetadata,
    repositoryReadMetadata:
        repositoryReadMetadata ?? this.repositoryReadMetadata,
  );
}
