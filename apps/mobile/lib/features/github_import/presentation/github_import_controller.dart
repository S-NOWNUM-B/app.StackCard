import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/github_failure.dart';
import '../domain/github_filters.dart';
import '../domain/github_import_repository.dart';
import '../domain/github_read_metadata.dart';
import '../domain/github_repository.dart';
import '../github_import_providers.dart';
import 'github_import_state.dart';

final githubImportControllerProvider =
    NotifierProvider.autoDispose<GitHubImportController, GitHubImportState>(
      GitHubImportController.new,
    );

class GitHubImportController extends Notifier<GitHubImportState> {
  late GitHubImportRepository _repository;
  late DateTime Function() _now;
  Timer? _queryTimer;
  int _generation = 0;

  @override
  GitHubImportState build() {
    final repository = ref.watch(githubImportRepositoryProvider);
    _repository = repository;
    _now = ref.watch(githubImportClockProvider);
    ref.onDispose(() {
      _generation++;
      _queryTimer?.cancel();
      repository.cancelRequests();
    });
    return GitHubImportState();
  }

  Future<void> load(String value) async {
    if (!_canRequest()) return;
    final username = normalizeGitHubUsername(value);
    if (state.username == username && (state.loading || state.refreshing)) {
      return;
    }
    if (validateGitHubUsername(username) != null) {
      _beginOperation();
      _queryTimer?.cancel();
      state = GitHubImportState(
        username: username,
        failure: const GitHubFailure(GitHubFailureKind.invalidUsername),
      );
      return;
    }
    if (state.username == username && state.profile != null) {
      await refresh();
      return;
    }

    final operationRef = ref;
    final repository = _repository;
    final generation = _beginOperation();
    final changedUsername = username != state.username;
    if (changedUsername) _queryTimer?.cancel();
    state = GitHubImportState(
      username: username,
      loading: true,
      query: changedUsername ? '' : state.query,
      filter: changedUsername ? GitHubRepositoryFilter.all : state.filter,
    );
    try {
      final profile = await repository.getProfile(username);
      if (!_isCurrent(generation, operationRef)) return;
      final page = await repository.getRepositories(profile);
      if (!_isCurrent(generation, operationRef)) return;
      state = state.copyWith(
        profile: profile,
        repositories: _mergeRepositories(const [], page.repositories),
        repositoryReadMetadata: _pageRepositoryMetadata(page),
        nextPage: page.nextPage,
        loading: false,
        failure: null,
        readMetadata: combineGitHubReadMetadata([
          profile.readMetadata,
          page.readMetadata,
        ]),
      );
    } on GitHubFailure catch (failure) {
      _finishFailure(generation, operationRef, failure);
    } on Exception {
      _finishFailure(
        generation,
        operationRef,
        const GitHubFailure(GitHubFailureKind.invalidResponse),
      );
    }
  }

  Future<void> refresh() async {
    if (state.loading || state.refreshing || !_canRequest()) return;
    if (state.profile == null) {
      await load(state.username);
      return;
    }
    final operationRef = ref;
    final repository = _repository;
    final username = state.username;
    final generation = _beginOperation();
    state = state.copyWith(
      refreshing: true,
      loadingMore: false,
      failure: null,
      pageFailure: null,
    );
    try {
      final profile = await repository.getProfile(username);
      if (!_isCurrent(generation, operationRef)) return;
      final page = await repository.getRepositories(profile);
      if (!_isCurrent(generation, operationRef)) return;
      state = state.copyWith(
        profile: profile,
        repositories: _mergeRepositories(const [], page.repositories),
        repositoryReadMetadata: _pageRepositoryMetadata(page),
        nextPage: page.nextPage,
        refreshing: false,
        failure: null,
        readMetadata: combineGitHubReadMetadata([
          profile.readMetadata,
          page.readMetadata,
        ]),
      );
    } on GitHubFailure catch (failure) {
      _finishFailure(generation, operationRef, failure);
    } on Exception {
      _finishFailure(
        generation,
        operationRef,
        const GitHubFailure(GitHubFailureKind.invalidResponse),
      );
    }
  }

  Future<void> loadMore() async {
    final profile = state.profile;
    final nextPage = state.nextPage;
    if (profile == null ||
        nextPage == null ||
        state.loading ||
        state.refreshing ||
        state.loadingMore ||
        !_canRequest()) {
      return;
    }
    final operationRef = ref;
    final repository = _repository;
    final generation = _beginOperation();
    state = state.copyWith(loadingMore: true, pageFailure: null);
    try {
      final page = await repository.getRepositories(profile, page: nextPage);
      if (!_isCurrent(generation, operationRef)) return;
      state = state.copyWith(
        repositories: _mergeRepositories(state.repositories, page.repositories),
        repositoryReadMetadata: _pageRepositoryMetadata(
          page,
          previous: state.repositoryReadMetadata,
        ),
        nextPage: page.nextPage,
        loadingMore: false,
        pageFailure: null,
        readMetadata: combineGitHubReadMetadata([
          state.readMetadata,
          page.readMetadata,
        ]),
      );
    } on GitHubFailure catch (failure) {
      _finishFailure(generation, operationRef, failure, pagination: true);
    } on Exception {
      _finishFailure(
        generation,
        operationRef,
        const GitHubFailure(GitHubFailureKind.invalidResponse),
        pagination: true,
      );
    }
  }

  Future<void> retry() =>
      state.profile == null ? load(state.username) : refresh();

  void setQuery(String query) {
    _queryTimer?.cancel();
    final queryRef = ref;
    _queryTimer = Timer(const Duration(milliseconds: 300), () {
      if (queryRef.mounted) state = state.copyWith(query: query);
    });
  }

  void setFilter(GitHubRepositoryFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void resetFilters() {
    _queryTimer?.cancel();
    state = state.copyWith(query: '', filter: GitHubRepositoryFilter.all);
  }

  bool _canRequest() {
    final now = _now();
    return ![state.failure, state.pageFailure].any((failure) {
      final retryAt = failure?.retryAt;
      return failure?.kind == GitHubFailureKind.rateLimited &&
          retryAt != null &&
          now.isBefore(retryAt);
    });
  }

  int _beginOperation() {
    _generation++;
    if (state.loading || state.refreshing || state.loadingMore) {
      _repository.cancelRequests();
    }
    return _generation;
  }

  bool _isCurrent(int generation, Ref operationRef) =>
      operationRef.mounted && generation == _generation;

  void _finishFailure(
    int generation,
    Ref operationRef,
    GitHubFailure failure, {
    bool pagination = false,
  }) {
    if (!_isCurrent(generation, operationRef)) return;
    final visibleFailure = failure.kind == GitHubFailureKind.cancelled
        ? null
        : failure;
    state = pagination
        ? state.copyWith(loadingMore: false, pageFailure: visibleFailure)
        : state.copyWith(
            loading: false,
            refreshing: false,
            failure: visibleFailure,
          );
  }
}

List<GitHubRepository> _mergeRepositories(
  Iterable<GitHubRepository> previous,
  Iterable<GitHubRepository> incoming,
) => <int, GitHubRepository>{
  for (final repository in previous) repository.id: repository,
  for (final repository in incoming) repository.id: repository,
}.values.toList(growable: false);

// Incoming payloads win duplicate IDs, so their page provenance must win too.
Map<int, GitHubReadMetadata> _pageRepositoryMetadata(
  GitHubRepositoriesPage page, {
  Map<int, GitHubReadMetadata> previous = const {},
}) => {
  ...previous,
  for (final repository in page.repositories) repository.id: page.readMetadata,
};
