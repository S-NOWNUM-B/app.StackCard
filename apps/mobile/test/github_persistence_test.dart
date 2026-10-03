import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_stackcard/features/github_import/data/dio_github_import_repository.dart';
import 'package:app_stackcard/features/github_import/data/github_response_cache.dart';
import 'package:app_stackcard/features/github_import/data/hive_github_response_cache.dart';
import 'package:app_stackcard/features/github_import/domain/github_failure.dart';
import 'package:app_stackcard/features/github_import/domain/github_import_repository.dart';
import 'package:app_stackcard/features/github_import/domain/github_profile.dart';
import 'package:app_stackcard/features/github_import/domain/github_read_metadata.dart';
import 'package:app_stackcard/features/github_import/domain/github_repository.dart';
import 'package:app_stackcard/features/github_import/github_import_providers.dart';
import 'package:app_stackcard/features/github_import/presentation/github_import_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late HiveInterface hive;
  late Box<dynamic> box;
  late DateTime now;
  late HiveGitHubResponseCache cache;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'stackcard-github-cache-',
    );
    hive = Hive..init(directory.path);
    box = await hive.openBox<dynamic>('github_http_v1');
    now = DateTime.utc(2026, 10, 3, 12);
    cache = HiveGitHubResponseCache(box, clock: () => now);
  });
  tearDown(() async {
    await hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'Hive reopen restores body, ETag, Link and original validation date',
    () async {
      final checked = now;
      const link = '<https://api.github.com/user/1/repos?page=2>; rel="next"';
      await cache.write(
        _repositoriesUri.toString(),
        CachedGitHubResponse(
          body: jsonEncode([_repositoryJson()]),
          etag: '"v1"',
          link: link,
          validatedAt: checked,
        ),
      );
      await hive.close();
      hive = Hive..init(directory.path);
      box = await hive.openBox<dynamic>('github_http_v1');
      now = now.add(const Duration(days: 2));
      cache = HiveGitHubResponseCache(box, clock: () => now);
      final restored = await cache.read(_repositoriesUri.toString());
      expect(jsonDecode(restored!.body).single['id'], 1);
      expect(restored.etag, '"v1"');
      expect(restored.link, link);
      expect(restored.validatedAt, checked);
    },
  );

  test(
    'hard TTL is valid just before seven days and expires at the boundary',
    () async {
      await cache.write(
        'entry',
        CachedGitHubResponse(body: '{}', validatedAt: now),
      );
      now = now.add(githubCacheMaxAge - const Duration(milliseconds: 1));
      expect(await cache.read('entry'), isNotNull);
      now = now.add(const Duration(milliseconds: 1));
      expect(await cache.read('entry'), isNull);
      expect(box.containsKey('entry'), false);
    },
  );

  test(
    'corrupt, unsupported and future-dated entries are isolated from draft',
    () async {
      final draft = await hive.openBox<dynamic>('portfolio_draft_v1');
      await draft.put('guest', 'unsynchronized draft');
      await cache.write(
        'good',
        CachedGitHubResponse(body: '{}', validatedAt: now),
      );
      final envelope = _envelope('{}', now);
      for (final raw in <Object>[
        42,
        {'unexpected': 'map'},
        '{invalid',
        jsonEncode({...envelope, 'schemaVersion': 2}),
        jsonEncode({...envelope, 'schemaVersion': 1.0}),
        jsonEncode({...envelope, 'body': []}),
        jsonEncode({...envelope, 'body': '{invalid'}),
        jsonEncode({...envelope, 'etag': 2}),
        jsonEncode({...envelope, 'link': false}),
        jsonEncode({...envelope, 'validatedAt': -1}),
        jsonEncode({...envelope, 'validatedAt': 'today'}),
        jsonEncode({
          ...envelope,
          'validatedAt': now
              .add(const Duration(seconds: 1))
              .millisecondsSinceEpoch,
        }),
      ]) {
        await box.put('bad', raw);
        expect(await cache.read('bad'), isNull, reason: raw.toString());
        expect(box.containsKey('bad'), false);
        expect(await cache.read('good'), isNotNull);
        expect(draft.get('guest'), 'unsynchronized draft');
      }
    },
  );

  test('restart offline restores profile and each cached page without renewing TTL', () async {
    final client = _client(
      cache,
      (request, _) => request.uri.path.endsWith('/repos')
          ? _reply(
              [
                _repositoryJson(
                  id: request.uri.queryParameters['page'] == '2' ? 2 : 1,
                ),
              ],
              link: request.uri.queryParameters['page'] == '2'
                  ? null
                  : '<https://api.github.com/user/1/repos?page=2>; rel="next"',
            )
          : _reply(_profileJson()),
      clock: () => now,
    );
    final profile = await client.repository.getProfile('alice');
    final first = await client.repository.getRepositories(profile);
    await client.repository.getRepositories(profile, page: first.nextPage);
    final checked = now;
    await hive.close();
    hive = Hive..init(directory.path);
    box = await hive.openBox<dynamic>('github_http_v1');
    now = now.add(const Duration(days: 1));
    cache = HiveGitHubResponseCache(box, clock: () => now);
    final offline = _client(cache, _networkError, clock: () => now);
    final scope = _scope(offline.repository);
    await scope.controller.load('alice');
    await scope.controller.loadMore();
    final state = scope.container.read(githubImportControllerProvider);
    expect(state.repositories.map((item) => item.id), [1, 2]);
    expect(state.profile!.login, 'alice');
    expect(state.readMetadata.fromCache, true);
    expect(state.readMetadata.validatedAt, checked);
    expect(state.readMetadata.fallbackFailure!.kind, GitHubFailureKind.network);
    expect(state.failure, isNull);
    expect(state.pageFailure, isNull);
    expect((await cache.read(_profileUri.toString()))!.validatedAt, checked);
  });

  for (final kind in [
    GitHubFailureKind.network,
    GitHubFailureKind.timeout,
    GitHubFailureKind.server,
  ]) {
    test('validated cache fallback is allowed for ${kind.name}', () async {
      final checked = now;
      await cache.write(
        _profileUri.toString(),
        CachedGitHubResponse(
          body: jsonEncode(_profileJson()),
          etag: '"old"',
          validatedAt: checked,
        ),
      );
      now = now.add(const Duration(hours: 2));
      final client = _client(cache, (request, _) {
        if (kind == GitHubFailureKind.server) {
          return _reply({'message': 'Unavailable'}, status: 503);
        }
        throw DioException(
          requestOptions: request,
          type: kind == GitHubFailureKind.network
              ? DioExceptionType.connectionError
              : DioExceptionType.receiveTimeout,
        );
      }, clock: () => now);
      final profile = await client.repository.getProfile('alice');
      expect(profile.readMetadata.fromCache, true);
      expect(profile.readMetadata.validatedAt, checked);
      expect(profile.readMetadata.fallbackFailure!.kind, kind);
      expect(client.adapter.requests.single.headers['If-None-Match'], '"old"');
    });
  }

  for (final entry in {
    404: GitHubFailureKind.notFound,
    403: GitHubFailureKind.forbidden,
    429: GitHubFailureKind.rateLimited,
  }.entries) {
    test(
      '${entry.value.name} is not hidden by a valid persisted cache',
      () async {
        await cache.write(
          _profileUri.toString(),
          CachedGitHubResponse(
            body: jsonEncode(_profileJson()),
            validatedAt: now,
          ),
        );
        final client = _client(
          cache,
          (_, _) => _reply({'message': 'Failure'}, status: entry.key),
          clock: () => now,
        );
        await expectLater(
          client.repository.getProfile('alice'),
          _failure(entry.value),
        );
      },
    );
  }

  test('invalid HTTP response is not replaced by cache and leaves the old entry intact', () async {
    await cache.write(
      _profileUri.toString(),
      CachedGitHubResponse(
        body: jsonEncode(_profileJson()),
        etag: '"valid"',
        validatedAt: now,
      ),
    );
    final client = _client(
      cache,
      (_, _) => _reply({'id': 'broken'}),
      clock: () => now,
    );
    await expectLater(
      client.repository.getProfile('alice'),
      _failure(GitHubFailureKind.invalidResponse),
    );
    expect((await cache.read(_profileUri.toString()))!.etag, '"valid"');
  });

  test(
    'corrupt DTO body is evicted before a conditional request or fallback',
    () async {
      await cache.write(
        _profileUri.toString(),
        CachedGitHubResponse(
          body: jsonEncode({..._profileJson(), 'id': 'invalid'}),
          etag: '"bad"',
          validatedAt: now,
        ),
      );
      final client = _client(cache, _networkError, clock: () => now);
      await expectLater(
        client.repository.getProfile('alice'),
        _failure(GitHubFailureKind.network),
      );
      expect(
        client.adapter.requests.single.headers.containsKey('If-None-Match'),
        false,
      );
      expect(box.containsKey(_profileUri.toString()), false);
    },
  );

  test(
    'unsafe cached Link is evicted instead of following or showing it',
    () async {
      await cache.write(
        _repositoriesUri.toString(),
        CachedGitHubResponse(
          body: jsonEncode([_repositoryJson()]),
          etag: '"bad"',
          link: '<https://evil.example/repos>; rel="next"',
          validatedAt: now,
        ),
      );
      final client = _client(cache, _networkError, clock: () => now);
      await expectLater(
        client.repository.getRepositories(_profile()),
        _failure(GitHubFailureKind.network),
      );
      expect(
        client.adapter.requests.single.headers.containsKey('If-None-Match'),
        false,
      );
      expect(box.containsKey(_repositoriesUri.toString()), false);
    },
  );

  test(
    'malformed JSON cache recovers through a new valid 200 response',
    () async {
      await box.put(_profileUri.toString(), jsonEncode(_envelope('{bad', now)));
      final client = _client(
        cache,
        (_, _) => _reply(_profileJson(), etag: '"new"'),
        clock: () => now,
      );
      final profile = await client.repository.getProfile('alice');
      expect(profile.readMetadata.fromCache, false);
      expect(
        client.adapter.requests.single.headers.containsKey('If-None-Match'),
        false,
      );
      expect((await cache.read(_profileUri.toString()))!.etag, '"new"');
    },
  );

  test(
    '304 refreshes TTL and validators and reconnect clears offline metadata',
    () async {
      var offline = false;
      var requests = 0;
      final checked = now;
      final client = _client(cache, (request, _) {
        if (offline) return _networkError(request, null);
        return ++requests == 1
            ? _reply(_profileJson(), etag: '"v1"')
            : _reply(null, status: 304, etag: '"v2"');
      }, clock: () => now);
      await client.repository.getProfile('alice');
      now = checked.add(const Duration(days: 6));
      offline = true;
      expect(
        (await client.repository.getProfile('alice')).readMetadata.fromCache,
        true,
      );
      offline = false;
      final reconnected = await client.repository.getProfile('alice');
      expect(reconnected.readMetadata.fromCache, false);
      expect(reconnected.readMetadata.fallbackFailure, isNull);
      expect(reconnected.readMetadata.validatedAt, now);
      expect(client.adapter.requests.last.headers['If-None-Match'], '"v1"');
      final renewed = await cache.read(_profileUri.toString());
      expect(renewed!.validatedAt, now);
      expect(renewed.etag, '"v2"');
      now = now.add(const Duration(days: 6));
      offline = true;
      expect(
        (await client.repository.getProfile('alice')).readMetadata.fromCache,
        true,
      );
    },
  );

  test('expired cache cannot provide fallback or an ETag', () async {
    await cache.write(
      _profileUri.toString(),
      CachedGitHubResponse(
        body: jsonEncode(_profileJson()),
        etag: '"expired"',
        validatedAt: now,
      ),
    );
    now = now.add(githubCacheMaxAge);
    final client = _client(cache, _networkError, clock: () => now);
    await expectLater(
      client.repository.getProfile('alice'),
      _failure(GitHubFailureKind.network),
    );
    expect(
      client.adapter.requests.single.headers.containsKey('If-None-Match'),
      false,
    );
  });

  test(
    'cache that expires during transport cannot provide late fallback',
    () async {
      await cache.write(
        _profileUri.toString(),
        CachedGitHubResponse(
          body: jsonEncode(_profileJson()),
          validatedAt: now,
        ),
      );
      now = now.add(githubCacheMaxAge - const Duration(seconds: 1));
      final pending = Completer<ResponseBody>();
      final started = Completer<RequestOptions>();
      final client = _client(cache, (request, _) {
        started.complete(request);
        return pending.future;
      }, clock: () => now);
      final result = client.repository.getProfile('alice');
      final expectation = expectLater(
        result,
        _failure(GitHubFailureKind.timeout),
      );
      final request = await started.future;
      now = now.add(const Duration(seconds: 1));
      pending.completeError(
        DioException(
          requestOptions: request,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await expectation;
    },
  );

  test('closed Hive storage reports read/write problems without failing valid HTTP', () async {
    await box.close();
    final client = _client(
      cache,
      (_, _) => _reply(_profileJson()),
      clock: () => now,
    );
    final profile = await client.repository.getProfile('alice');
    expect(profile.readMetadata.fromCache, false);
    expect(profile.readMetadata.cacheUnavailable, true);
    expect(profile.readMetadata.cacheWriteFailed, true);
    expect(profile.readMetadata.validatedAt, now);
  });

  test(
    'write failure marks a successful response as unavailable offline',
    () async {
      final client = _client(
        _WriteFailureCache(),
        (_, _) => _reply(_profileJson()),
        clock: () => now,
      );
      final profile = await client.repository.getProfile('alice');
      expect(profile.readMetadata.cacheWriteFailed, true);
      expect(profile.readMetadata.cacheUnavailable, false);
    },
  );

  test(
    'cancellation while awaiting storage write still ends as cancelled',
    () async {
      final delayed = _DelayedWriteCache();
      final client = _client(
        delayed,
        (_, _) => _reply(_profileJson()),
        clock: () => now,
      );
      final result = client.repository.getProfile('alice');
      final expectation = expectLater(
        result,
        _failure(GitHubFailureKind.cancelled),
      );
      await delayed.started.future;
      client.repository.cancelRequests();
      delayed.done.complete();
      await expectation;
    },
  );

  test(
    'cancellation while evicting corrupt storage never starts HTTP',
    () async {
      final delayed = _DelayedEvictionCache(now);
      final client = _client(
        delayed,
        (_, _) => _reply(_profileJson()),
        clock: () => now,
      );
      final result = client.repository.getProfile('alice');
      final expectation = expectLater(
        result,
        _failure(GitHubFailureKind.cancelled),
      );
      await delayed.started.future;
      client.repository.cancelRequests();
      delayed.done.complete();
      await expectation;
      expect(client.adapter.requests, isEmpty);
    },
  );

  test('cancelled transport does not turn into an offline success', () async {
    await cache.write(
      _profileUri.toString(),
      CachedGitHubResponse(body: jsonEncode(_profileJson()), validatedAt: now),
    );
    final client = _client(
      cache,
      (request, _) => throw DioException(
        requestOptions: request,
        type: DioExceptionType.cancel,
      ),
      clock: () => now,
    );
    await expectLater(
      client.repository.getProfile('alice'),
      _failure(GitHubFailureKind.cancelled),
    );
  });

  test(
    'controller aggregates mixed pages and fresh refresh clears every warning',
    () async {
      final old = now.subtract(const Duration(days: 1));
      final source = _MixedRepository(old, now);
      final scope = _scope(source);
      await scope.controller.load('alice');
      var state = scope.container.read(githubImportControllerProvider);
      expect(state.readMetadata.fromCache, true);
      expect(state.readMetadata.validatedAt, old);
      expect(state.readMetadata.cacheWriteFailed, true);
      await scope.controller.loadMore();
      state = scope.container.read(githubImportControllerProvider);
      expect(state.repositories, hasLength(2));
      expect(state.readMetadata.fromCache, true);
      expect(state.readMetadata.validatedAt, old);
      source.fresh = true;
      await scope.controller.refresh();
      state = scope.container.read(githubImportControllerProvider);
      expect(state.readMetadata.fromCache, false);
      expect(state.readMetadata.fallbackFailure, isNull);
      expect(state.readMetadata.cacheWriteFailed, false);
      expect(state.readMetadata.cacheUnavailable, false);
      expect(state.readMetadata.validatedAt, now);
    },
  );
}

final _profileUri = Uri.parse('https://api.github.com/users/alice');
final _repositoriesUri = Uri.https('api.github.com', '/users/alice/repos', {
  'type': 'owner',
  'sort': 'updated',
  'direction': 'desc',
  'per_page': '30',
});

Map<String, Object?> _envelope(String body, DateTime checked) => {
  'schemaVersion': 1,
  'body': body,
  'etag': '"v1"',
  'link': null,
  'validatedAt': checked.millisecondsSinceEpoch,
};
Map<String, Object?> _profileJson() => {
  'id': 1,
  'login': 'alice',
  'html_url': 'https://github.com/alice',
  'public_repos': 2,
};
Map<String, Object?> _repositoryJson({int id = 1}) => {
  'id': id,
  'name': 'Repository $id',
  'full_name': 'alice/repository-$id',
  'html_url': 'https://github.com/alice/repository-$id',
  'stargazers_count': 0,
  'forks_count': 0,
  'fork': false,
  'archived': false,
  'updated_at': '2026-10-03T12:00:00Z',
};
GitHubProfile _profile({
  GitHubReadMetadata metadata = const GitHubReadMetadata(),
}) => GitHubProfile(
  id: 1,
  login: 'alice',
  htmlUrl: 'https://github.com/alice',
  publicRepositories: 2,
  readMetadata: metadata,
);
GitHubRepository _repository(int id) => GitHubRepository(
  id: id,
  name: 'Repository $id',
  fullName: 'alice/repository-$id',
  htmlUrl: 'https://github.com/alice/repository-$id',
  stars: 0,
  forks: 0,
  isFork: false,
  archived: false,
  updatedAt: DateTime.utc(2026, 10, 3),
);
Matcher _failure(GitHubFailureKind kind) =>
    throwsA(isA<GitHubFailure>().having((error) => error.kind, 'kind', kind));
ResponseBody _networkError(RequestOptions request, Future<void>? _) =>
    throw DioException(
      requestOptions: request,
      type: DioExceptionType.connectionError,
    );
ResponseBody _reply(
  Object? body, {
  int status = 200,
  String? etag,
  String? link,
}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
    if (etag != null) 'etag': [etag],
    if (link != null) 'link': [link],
  },
);

({DioGitHubImportRepository repository, _Adapter adapter}) _client(
  GitHubResponseCache cache,
  FutureOr<ResponseBody> Function(RequestOptions, Future<void>?) respond, {
  required DateTime Function() clock,
}) {
  final adapter = _Adapter(respond);
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(() => dio.close(force: true));
  return (
    repository: DioGitHubImportRepository(dio, cache: cache, clock: clock),
    adapter: adapter,
  );
}

({ProviderContainer container, GitHubImportController controller}) _scope(
  GitHubImportRepository repository,
) {
  final container = ProviderContainer.test(
    overrides: [githubImportRepositoryProvider.overrideWithValue(repository)],
  );
  container.listen(githubImportControllerProvider, (_, _) {});
  return (
    container: container,
    controller: container.read(githubImportControllerProvider.notifier),
  );
}

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions, Future<void>?) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

class _WriteFailureCache implements GitHubResponseCache {
  @override
  Future<CachedGitHubResponse?> read(String key) async => null;
  @override
  Future<void> write(String key, CachedGitHubResponse response) async =>
      throw const FileSystemException('Storage unavailable');
}

final class _DelayedWriteCache extends _WriteFailureCache {
  final started = Completer<void>();
  final done = Completer<void>();
  @override
  Future<void> write(String key, CachedGitHubResponse response) {
    started.complete();
    return done.future;
  }
}

final class _DelayedEvictionCache implements EvictableGitHubResponseCache {
  _DelayedEvictionCache(this.now);
  final DateTime now;
  final started = Completer<void>();
  final done = Completer<void>();
  @override
  Future<CachedGitHubResponse?> read(String key) async =>
      CachedGitHubResponse(body: '{bad', validatedAt: now);
  @override
  Future<void> remove(String key) {
    started.complete();
    return done.future;
  }

  @override
  Future<void> write(String key, CachedGitHubResponse response) async {}
}

final class _MixedRepository implements GitHubImportRepository {
  _MixedRepository(this.old, this.now);
  final DateTime old;
  final DateTime now;
  bool fresh = false;
  @override
  Future<GitHubProfile> getProfile(String username) async => _profile(
    metadata: GitHubReadMetadata(validatedAt: now, cacheWriteFailed: !fresh),
  );
  @override
  Future<GitHubRepositoriesPage> getRepositories(
    GitHubProfile profile, {
    Uri? page,
  }) async => GitHubRepositoriesPage(
    repositories: [_repository(page == null ? 1 : 2)],
    nextPage: page == null
        ? Uri.parse('https://api.github.com/user/1/repos?page=2')
        : null,
    readMetadata: page != null || fresh
        ? GitHubReadMetadata(validatedAt: now)
        : GitHubReadMetadata(
            fromCache: true,
            validatedAt: old,
            fallbackFailure: const GitHubFailure(GitHubFailureKind.network),
          ),
  );
  @override
  void cancelRequests() {}
}
