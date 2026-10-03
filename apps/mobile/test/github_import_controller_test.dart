import 'dart:async';

import 'package:app_stackcard/features/github_import/domain/github_failure.dart';
import 'package:app_stackcard/features/github_import/domain/github_filters.dart';
import 'package:app_stackcard/features/github_import/domain/github_import_repository.dart';
import 'package:app_stackcard/features/github_import/domain/github_profile.dart';
import 'package:app_stackcard/features/github_import/domain/github_repository.dart';
import 'package:app_stackcard/features/github_import/github_import_providers.dart';
import 'package:app_stackcard/features/github_import/presentation/github_import_controller.dart';
import 'package:app_stackcard/features/github_import/presentation/github_import_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Initial load normalizes username and commits the complete snapshot',
    () async {
      final repository = _FakeRepository();
      final scope = _scope(repository);
      await scope.controller.load('  ALICE  ');

      final state = scope.container.read(githubImportControllerProvider);
      expect(repository.usernames, ['alice']);
      expect(state.username, 'alice');
      expect(state.profile!.login, 'alice');
      expect(state.repositories.map((item) => item.id), [1]);
      expect(state.loading, isFalse);
      expect(state.failure, isNull);
      expect(() => state.repositories.clear(), throwsUnsupportedError);
      expect(() => state.visibleRepositories.clear(), throwsUnsupportedError);
    },
  );

  test(
    'Invalid username cancels the previous load without starting HTTP',
    () async {
      final pending = Completer<GitHubProfile>();
      final repository = _FakeRepository(profile: (_) => pending.future);
      final scope = _scope(repository);
      final loading = scope.controller.load('alice');
      await scope.controller.load('bad--name');
      pending.complete(_profile('alice'));
      await loading;

      final state = scope.container.read(githubImportControllerProvider);
      expect(repository.usernames, ['alice']);
      expect(repository.pages, isEmpty);
      expect(repository.cancellations, 1);
      expect(state.failure!.kind, GitHubFailureKind.invalidUsername);
      expect(state.loading, isFalse);
      expect(state.profile, isNull);
    },
  );

  test('Initial repository failure leaves no partial profile and retries explicitly', () async {
    var reads = 0;
    final repository = _FakeRepository(
      repositories: (_, _) async {
        reads++;
        if (reads == 1) throw const GitHubFailure(GitHubFailureKind.network);
        return _page([_repository(2)]);
      },
    );
    final scope = _scope(repository);
    await scope.controller.load('alice');

    var state = scope.container.read(githubImportControllerProvider);
    expect(state.profile, isNull);
    expect(state.repositories, isEmpty);
    expect(state.failure!.kind, GitHubFailureKind.network);
    expect(repository.usernames, ['alice']);
    await scope.container.pump();
    expect(reads, 1);

    await scope.controller.retry();
    state = scope.container.read(githubImportControllerProvider);
    expect(state.repositories.single.id, 2);
    expect(state.failure, isNull);
    expect(repository.usernames, ['alice', 'alice']);
  });

  test(
    'New username replaces a pending load and ignores its late response',
    () async {
      final oldProfile = Completer<GitHubProfile>();
      final repository = _FakeRepository(
        profile: (username) async {
          if (username == 'alice') return oldProfile.future;
          return _profile(username);
        },
      );
      final scope = _scope(repository);
      final oldLoad = scope.controller.load('alice');
      await scope.controller.load('bob');
      oldProfile.complete(_profile('alice'));
      await oldLoad;

      final state = scope.container.read(githubImportControllerProvider);
      expect(state.username, 'bob');
      expect(state.profile!.login, 'bob');
      expect(repository.repositoryOwners, ['bob']);
      expect(repository.cancellations, 1);
    },
  );

  test(
    'Pagination deduplicates stable ids and keeps the original order',
    () async {
      final next = Uri.parse('https://api.github.com/users/alice/repos?page=2');
      final repository = _FakeRepository(
        repositories: (_, page) async {
          return page == null
              ? _page([_repository(1), _repository(2)], next: next)
              : _page([_repository(1, name: 'Updated'), _repository(3)]);
        },
      );
      final scope = _scope(repository);
      await scope.controller.load('alice');
      await scope.controller.loadMore();
      await scope.controller.loadMore();

      final state = scope.container.read(githubImportControllerProvider);
      expect(state.repositories.map((item) => item.id), [1, 2, 3]);
      expect(state.repositories.first.name, 'Updated');
      expect(state.nextPage, isNull);
      expect(repository.pages, [null, next]);
    },
  );

  test(
    'Pagination failure retains the list and retries the same page only',
    () async {
      final next = Uri.parse('https://api.github.com/users/alice/repos?page=2');
      var requests = 0;
      final repository = _FakeRepository(
        repositories: (_, page) async {
          if (page == null) {
            return _page([_repository(1)], next: next);
          }
          requests++;
          if (requests == 1) {
            throw const GitHubFailure(GitHubFailureKind.timeout);
          }
          return _page([_repository(2)]);
        },
      );
      final scope = _scope(repository);
      await scope.controller.load('alice');
      await scope.controller.loadMore();
      var state = scope.container.read(githubImportControllerProvider);
      expect(state.repositories.single.id, 1);
      expect(state.nextPage, next);
      expect(state.pageFailure!.kind, GitHubFailureKind.timeout);
      expect(state.failure, isNull);
      expect(state.loadingMore, isFalse);

      await scope.controller.loadMore();
      state = scope.container.read(githubImportControllerProvider);
      expect(state.repositories.map((item) => item.id), [1, 2]);
      expect(state.pageFailure, isNull);
      expect(repository.usernames, ['alice']);
      expect(repository.pages, [null, next, next]);
    },
  );

  test('Refresh failure keeps the last successful profile and list', () async {
    var profileReads = 0;
    final pending = Completer<GitHubProfile>();
    final repository = _FakeRepository(
      profile: (username) async {
        profileReads++;
        return profileReads == 1 ? _profile(username) : pending.future;
      },
    );
    final scope = _scope(repository);
    await scope.controller.load('alice');
    final previous = scope.container.read(githubImportControllerProvider);
    final refresh = scope.controller.refresh();
    expect(
      scope.container.read(githubImportControllerProvider).refreshing,
      isTrue,
    );
    expect(
      scope.container.read(githubImportControllerProvider).repositories,
      previous.repositories,
    );
    pending.completeError(const GitHubFailure(GitHubFailureKind.network));
    await refresh;

    final state = scope.container.read(githubImportControllerProvider);
    expect(state.profile, same(previous.profile));
    expect(state.repositories, previous.repositories);
    expect(state.refreshing, isFalse);
    expect(state.failure!.kind, GitHubFailureKind.network);
  });

  test(
    'Refresh supersedes loadMore and duplicate operations stay single',
    () async {
      final next = Uri.parse('https://api.github.com/users/alice/repos?page=2');
      final firstProfile = Completer<GitHubProfile>();
      final refreshedProfile = Completer<GitHubProfile>();
      final morePage = Completer<GitHubRepositoriesPage>();
      var firstPageReads = 0;
      final repository = _FakeRepository(
        profile: (_) => firstProfile.isCompleted
            ? refreshedProfile.future
            : firstProfile.future,
        repositories: (_, page) async {
          if (page != null) return morePage.future;
          firstPageReads++;
          return firstPageReads == 1
              ? _page([_repository(1)], next: next)
              : _page([_repository(7)]);
        },
      );
      final scope = _scope(repository);
      final load = scope.controller.load('alice');
      await scope.controller.load('alice');
      expect(repository.usernames, ['alice']);
      firstProfile.complete(_profile('alice'));
      await load;

      final more = scope.controller.loadMore();
      await scope.controller.loadMore();
      expect(repository.pages, [null, next]);
      final refresh = scope.controller.refresh();
      await scope.controller.refresh();
      expect(repository.usernames, ['alice', 'alice']);
      expect(repository.cancellations, 1);
      refreshedProfile.complete(_profile('alice'));
      await refresh;
      morePage.complete(_page([_repository(9)]));
      await more;

      final state = scope.container.read(githubImportControllerProvider);
      expect(state.repositories.single.id, 7);
      expect(state.loadingMore, isFalse);
      expect(state.refreshing, isFalse);
    },
  );

  test(
    'Main rate limit blocks retries and other usernames until its deadline',
    () async {
      var now = DateTime.utc(2026, 10, 3, 10);
      final deadline = now.add(const Duration(minutes: 1));
      final failure = GitHubFailure(
        GitHubFailureKind.rateLimited,
        retryAt: deadline,
      );
      var reads = 0;
      final repository = _FakeRepository(
        profile: (username) async {
          reads++;
          if (reads == 1) throw failure;
          return _profile(username);
        },
      );
      final scope = _scope(repository, now: () => now);
      await scope.controller.load('alice');
      await scope.controller.retry();
      await scope.controller.load('bob');
      expect(repository.usernames, ['alice']);
      expect(
        scope.container.read(githubImportControllerProvider).failure,
        same(failure),
      );

      now = deadline;
      await scope.controller.retry();
      expect(repository.usernames, ['alice', 'alice']);
      expect(
        scope.container.read(githubImportControllerProvider).failure,
        isNull,
      );
    },
  );

  test(
    'Pagination rate limit also blocks refresh until the deadline',
    () async {
      var now = DateTime.utc(2026, 10, 3, 10);
      final deadline = now.add(const Duration(minutes: 1));
      final next = Uri.parse('https://api.github.com/users/alice/repos?page=2');
      var moreReads = 0;
      final repository = _FakeRepository(
        repositories: (_, page) async {
          if (page == null) return _page([_repository(1)], next: next);
          moreReads++;
          if (moreReads == 1) {
            throw GitHubFailure(
              GitHubFailureKind.rateLimited,
              retryAt: deadline,
            );
          }
          return _page([_repository(2)]);
        },
      );
      final scope = _scope(repository, now: () => now);
      await scope.controller.load('alice');
      await scope.controller.loadMore();
      await scope.controller.loadMore();
      await scope.controller.refresh();
      expect(repository.usernames, ['alice']);
      expect(repository.pages, [null, next]);

      now = deadline;
      await scope.controller.loadMore();
      expect(repository.pages, [null, next, next]);
      expect(
        scope.container.read(githubImportControllerProvider).pageFailure,
        isNull,
      );
    },
  );

  test(
    'Cancelled current operation ends loading without displaying an error',
    () async {
      final repository = _FakeRepository(
        profile: (_) async {
          throw const GitHubFailure(GitHubFailureKind.cancelled);
        },
      );
      final scope = _scope(repository);
      await scope.controller.load('alice');
      final state = scope.container.read(githubImportControllerProvider);
      expect(state.loading, isFalse);
      expect(state.failure, isNull);
      expect(repository.pages, isEmpty);
    },
  );

  test(
    'Unexpected repository exception becomes a safe typed failure',
    () async {
      final repository = _FakeRepository(
        profile: (_) async {
          throw const FormatException('Internal response details');
        },
      );
      final scope = _scope(repository);
      await scope.controller.load('alice');
      expect(
        scope.container.read(githubImportControllerProvider).failure!.kind,
        GitHubFailureKind.invalidResponse,
      );
    },
  );

  test(
    'Auto-dispose cancels pending requests and ignores late results',
    () async {
      final pending = Completer<GitHubProfile>();
      final repository = _FakeRepository(profile: (_) => pending.future);
      final container = ProviderContainer.test(
        overrides: [
          githubImportRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final subscription = container.listen(
        githubImportControllerProvider,
        (_, _) {},
      );
      final controller = container.read(
        githubImportControllerProvider.notifier,
      );
      final load = controller.load('alice');
      subscription.close();
      await container.pump();
      expect(repository.cancellations, greaterThanOrEqualTo(1));
      pending.complete(_profile('alice'));
      await load;
      expect(repository.pages, isEmpty);
    },
  );

  testWidgets('Search debounces locally and refresh keeps query/filter', (
    tester,
  ) async {
    final repository = _FakeRepository(
      repositories: (_, _) async => _page([
        _repository(1, name: 'Flutter App'),
        _repository(2, name: 'Flutter Fork', fork: true),
        _repository(3, name: 'Other', fork: true),
      ]),
    );
    final scope = _scope(repository);
    await scope.controller.load('alice');
    scope.controller.setQuery('Other');
    await tester.pump(const Duration(milliseconds: 100));
    scope.controller.setQuery('Flutter');
    scope.controller.setFilter(GitHubRepositoryFilter.forks);
    await tester.pump(const Duration(milliseconds: 299));
    expect(scope.container.read(githubImportControllerProvider).query, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      scope.container
          .read(githubImportControllerProvider)
          .visibleRepositories
          .single
          .id,
      2,
    );
    expect(repository.pages, [null]);

    await scope.controller.refresh();
    final state = scope.container.read(githubImportControllerProvider);
    expect(state.query, 'Flutter');
    expect(state.filter, GitHubRepositoryFilter.forks);
    expect(state.visibleRepositories.single.id, 2);
    scope.controller.resetFilters();
    expect(
      scope.container
          .read(githubImportControllerProvider)
          .visibleRepositories
          .length,
      3,
    );
  });

  testWidgets('New username and reset cancel pending search', (tester) async {
    final repository = _FakeRepository();
    final scope = _scope(repository);
    await scope.controller.load('alice');
    scope.controller.setQuery('old filter');
    scope.controller.setFilter(GitHubRepositoryFilter.forks);
    await scope.controller.load('bob');
    await tester.pump(const Duration(milliseconds: 300));
    var state = scope.container.read(githubImportControllerProvider);
    expect(state.query, isEmpty);
    expect(state.filter, GitHubRepositoryFilter.all);

    scope.controller.setQuery('pending');
    scope.controller.resetFilters();
    await tester.pump(const Duration(milliseconds: 300));
    state = scope.container.read(githubImportControllerProvider);
    expect(state.query, isEmpty);
    expect(repository.usernames, ['alice', 'bob']);
  });

  testWidgets('Disposal cancels a debounce timer safely', (tester) async {
    final repository = _FakeRepository();
    final scope = _scope(repository);
    scope.controller.setQuery('pending');
    scope.container.dispose();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(repository.cancellations, greaterThanOrEqualTo(1));
  });

  test('State defends collections and copyWith can clear nullable fields', () {
    final repositories = [_repository(1)];
    final state = GitHubImportState(
      profile: _profile('alice'),
      repositories: repositories,
      nextPage: Uri.parse('https://api.github.com/users/alice/repos?page=2'),
      failure: const GitHubFailure(GitHubFailureKind.network),
      pageFailure: const GitHubFailure(GitHubFailureKind.timeout),
    );
    repositories.clear();
    final cleared = state.copyWith(
      profile: null,
      nextPage: null,
      failure: null,
      pageFailure: null,
    );
    expect(state.repositories.single.id, 1);
    expect(cleared.profile, isNull);
    expect(cleared.nextPage, isNull);
    expect(cleared.failure, isNull);
    expect(cleared.pageFailure, isNull);
  });
}

({ProviderContainer container, GitHubImportController controller}) _scope(
  _FakeRepository repository, {
  DateTime Function()? now,
}) {
  final container = ProviderContainer.test(
    overrides: [
      githubImportRepositoryProvider.overrideWithValue(repository),
      if (now != null) githubImportClockProvider.overrideWithValue(now),
    ],
  );
  container.listen(githubImportControllerProvider, (_, _) {});
  return (
    container: container,
    controller: container.read(githubImportControllerProvider.notifier),
  );
}

GitHubProfile _profile(String username) => GitHubProfile(
  id: username == 'alice' ? 1 : 2,
  login: username,
  htmlUrl: 'https://github.com/$username',
  publicRepositories: 3,
);

GitHubRepository _repository(int id, {String? name, bool fork = false}) =>
    GitHubRepository(
      id: id,
      name: name ?? 'Repository $id',
      fullName: 'alice/${name ?? 'repository-$id'}',
      htmlUrl: 'https://github.com/alice/repository-$id',
      stars: 0,
      forks: 0,
      isFork: fork,
      archived: false,
      updatedAt: DateTime.utc(2026, 10, 3),
    );

GitHubRepositoriesPage _page(
  List<GitHubRepository> repositories, {
  Uri? next,
}) => GitHubRepositoriesPage(repositories: repositories, nextPage: next);

final class _FakeRepository implements GitHubImportRepository {
  _FakeRepository({
    Future<GitHubProfile> Function(String)? profile,
    Future<GitHubRepositoriesPage> Function(GitHubProfile, Uri?)? repositories,
  }) : profile = profile ?? ((username) async => _profile(username)),
       repositories = repositories ?? ((_, _) async => _page([_repository(1)]));

  final Future<GitHubProfile> Function(String) profile;
  final Future<GitHubRepositoriesPage> Function(GitHubProfile, Uri?)
  repositories;
  final List<String> usernames = [];
  final List<String> repositoryOwners = [];
  final List<Uri?> pages = [];
  int cancellations = 0;

  @override
  Future<GitHubProfile> getProfile(String username) {
    usernames.add(username);
    return profile(username);
  }

  @override
  Future<GitHubRepositoriesPage> getRepositories(
    GitHubProfile profile, {
    Uri? page,
  }) {
    repositoryOwners.add(profile.login);
    pages.add(page);
    return repositories(profile, page);
  }

  @override
  void cancelRequests() => cancellations++;
}
