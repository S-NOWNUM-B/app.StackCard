import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_stackcard/features/github_import/data/dio_github_import_repository.dart';
import 'package:app_stackcard/features/github_import/data/github_profile_dto.dart';
import 'package:app_stackcard/features/github_import/data/github_repository_dto.dart';
import 'package:app_stackcard/features/github_import/data/github_response_cache.dart';
import 'package:app_stackcard/features/github_import/domain/github_failure.dart';
import 'package:app_stackcard/features/github_import/domain/github_profile.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GitHub JSON boundary', () {
    test('profile nullable public fields survive a DTO round trip', () {
      final dto = GitHubProfileDto.fromJson({
        ..._profileJson(),
        'login': 'OctoCat',
        'unknown': {'ignored': true},
      });
      expect(dto.profile.login, 'OctoCat');
      expect(dto.profile.name, isNull);
      expect(dto.profile.bio, isNull);
      expect(dto.profile.location, isNull);
      expect(dto.profile.publicRepositories, 8);
      expect(GitHubProfileDto.fromJson(dto.toJson()).toJson(), dto.toJson());
      expect(dto.toJson(), isNot(contains('unknown')));
    });

    test('repository metadata and UTC timestamp survive a DTO round trip', () {
      final dto = GitHubRepositoryDto.fromJson(_repositoryJson());
      expect(dto.repository.id, 1);
      expect(dto.repository.stars, 12);
      expect(dto.repository.forks, 3);
      expect(dto.repository.description, isNull);
      expect(dto.repository.language, isNull);
      expect(dto.repository.isFork, false);
      expect(dto.repository.archived, false);
      expect(dto.repository.updatedAt, DateTime.utc(2026, 10, 2, 12, 30));
      expect(GitHubRepositoryDto.fromJson(dto.toJson()).toJson(), dto.toJson());
    });

    test('profile required types, counts, username and URLs are strict', () {
      for (final change in <Map<String, Object?>>[
        {'id': 1.0},
        {'id': 0},
        {'login': null},
        {'login': 'bad--name'},
        {'login': ' padded '},
        {'name': false},
        {'bio': 2},
        {'location': []},
        {'avatar_url': 2},
        {'avatar_url': 'http://example.com/avatar'},
        {'html_url': 'https://user:password@github.com/octocat'},
        {'public_repos': -1},
        {'public_repos': '8'},
      ]) {
        expect(
          () => GitHubProfileDto.fromJson({..._profileJson(), ...change}),
          throwsFormatException,
          reason: change.toString(),
        );
      }
      expect(() => GitHubProfileDto.fromJson([]), throwsFormatException);
    });

    test('repository flags, counts, dates and required strings are strict', () {
      for (final change in <Map<String, Object?>>[
        {'id': -1},
        {'name': ''},
        {'full_name': false},
        {'description': 10},
        {'language': []},
        {'stargazers_count': 1.0},
        {'forks_count': -1},
        {'fork': 0},
        {'archived': null},
        {'html_url': 'javascript:alert(1)'},
        {'updated_at': 'yesterday'},
        {'updated_at': '2026-10-02'},
        {'updated_at': '2026-02-31T12:30:00Z'},
      ]) {
        expect(
          () => GitHubRepositoryDto.fromJson({..._repositoryJson(), ...change}),
          throwsFormatException,
          reason: change.toString(),
        );
      }
    });
  });

  group('GitHub HTTP and pagination', () {
    test(
      'normalizes username and sends the versioned public GET headers',
      () async {
        final client = _client((_, _) => _reply(_profileJson()));
        final profile = await client.repository.getProfile('  OctoCat  ');
        expect(profile.id, 583231);
        final request = client.adapter.requests.single;
        expect(request.method, 'GET');
        expect(request.uri, Uri.parse('https://api.github.com/users/octocat'));
        expect(request.headers['Accept'], 'application/vnd.github+json');
        expect(request.headers['X-GitHub-Api-Version'], '2026-03-10');
        expect(request.headers['User-Agent'], 'StackCard');
        expect(request.headers.containsKey('Authorization'), false);
        expect(request.followRedirects, false);
      },
    );

    test('invalid username never starts transport', () async {
      final client = _client((_, _) => _reply(_profileJson()));
      for (final username in ['', 'bad--name', 'bad/name', '-start']) {
        await expectLater(
          client.repository.getProfile(username),
          _failure(GitHubFailureKind.invalidUsername),
        );
      }
      expect(client.adapter.requests, isEmpty);
    });

    test('initial repository page has explicit supported query and immutable result', () async {
      final client = _client((_, _) => _reply([_repositoryJson()]));
      final page = await client.repository.getRepositories(_profile);
      expect(client.adapter.requests.single.uri.path, '/users/octocat/repos');
      expect(client.adapter.requests.single.uri.queryParameters, {
        'type': 'owner',
        'sort': 'updated',
        'direction': 'desc',
        'per_page': '30',
      });
      expect(page.repositories.single.fullName, 'octocat/Hello-World');
      expect(page.nextPage, isNull);
      expect(() => page.repositories.clear(), throwsUnsupportedError);
    });

    test('empty repository response is a successful last page', () async {
      final client = _client((_, _) => _reply([]));
      final page = await client.repository.getRepositories(_profile);
      expect(page.repositories, isEmpty);
      expect(page.nextPage, isNull);
    });

    test('follows the actual numeric-ID Link unchanged rather than reconstructing it', () async {
      const next =
          'https://api.github.com/user/583231/repos?per_page=30&page=2';
      final client = _client((request, _) {
        if (request.uri.queryParameters['page'] == '2') {
          return _reply([_repositoryJson(id: 2)]);
        }
        return _reply(
          [_repositoryJson()],
          link:
              '<$next>; rel="next", <https://api.github.com/user/583231/repos?per_page=30&page=8>; rel="last"',
        );
      });
      final first = await client.repository.getRepositories(_profile);
      expect(first.nextPage, Uri.parse(next));
      final second = await client.repository.getRepositories(
        _profile,
        page: first.nextPage,
      );
      expect(client.adapter.requests.last.uri.toString(), next);
      expect(second.repositories.single.id, 2);
      expect(second.nextPage, isNull);
    });

    test('accepts a verified canonical username Link too', () async {
      final pageUri = Uri.parse(
        'https://api.github.com/users/octocat/repos?page=2',
      );
      final client = _client((_, _) => _reply([]));
      await client.repository.getRepositories(_profile, page: pageUri);
      expect(client.adapter.requests.single.uri, pageUri);
    });

    test(
      'rejects unsafe or other-account page pointers before transport',
      () async {
        final client = _client((_, _) => _reply([]));
        for (final uri in [
          'http://api.github.com/users/octocat/repos?page=2',
          'https://evil.example/users/octocat/repos?page=2',
          'https://api.github.com/users/other/repos?page=2',
          'https://api.github.com/user/999/repos?page=2',
          'https://api.github.com/users/octocat/repos/extra?page=2',
          'https://token@api.github.com/users/octocat/repos?page=2',
          'https://api.github.com:444/users/octocat/repos?page=2',
          'https://api.github.com/users/octocat/repos?page=2#fragment',
        ]) {
          await expectLater(
            client.repository.getRepositories(_profile, page: Uri.parse(uri)),
            _failure(GitHubFailureKind.invalidResponse),
            reason: uri,
          );
        }
        expect(client.adapter.requests, isEmpty);
      },
    );

    test('invalid next Link does not commit body or ETag to cache', () async {
      final cache = _TrackingCache();
      final client = _client(
        (_, _) => _reply(
          [],
          etag: '"bad"',
          link: '<https://evil.example/repos>; rel="next"',
        ),
        cache: cache,
      );
      await expectLater(
        client.repository.getRepositories(_profile),
        _failure(GitHubFailureKind.invalidResponse),
      );
      expect(client.adapter.requests, hasLength(1));
      expect(cache.writes, isEmpty);
    });

    test('malformed Link syntax is an invalid response', () async {
      final client = _client(
        (_, _) => _reply([], link: 'not a Link; rel="next"'),
      );
      await expectLater(
        client.repository.getRepositories(_profile),
        _failure(GitHubFailureKind.invalidResponse),
      );
    });

    test('redirects are rejected and never automatically followed', () async {
      final client = _client(
        (_, _) => _reply(
          null,
          status: 302,
          headers: {
            'location': ['https://evil.example'],
          },
        ),
      );
      await expectLater(
        client.repository.getProfile('octocat'),
        _failure(GitHubFailureKind.invalidResponse),
      );
      expect(client.adapter.requests, hasLength(1));
    });
  });

  group('HTTP response cache', () {
    test('revalidates ETag and preserves cached pagination when 304 omits Link', () async {
      const link =
          '<https://api.github.com/user/583231/repos?per_page=30&page=2>; rel="next"';
      var responses = 0;
      final client = _client(
        (_, _) => ++responses == 1
            ? _reply([_repositoryJson()], etag: '"repos-v1"', link: link)
            : _reply(null, status: 304),
      );
      final first = await client.repository.getRepositories(_profile);
      final second = await client.repository.getRepositories(_profile);
      expect(client.adapter.requests, hasLength(2));
      expect(
        client.adapter.requests.last.headers['If-None-Match'],
        '"repos-v1"',
      );
      expect(second.repositories.single.id, first.repositories.single.id);
      expect(second.nextPage, first.nextPage);
    });

    test(
      '304 can update validators and Link while retaining parsed cached body',
      () async {
        var responses = 0;
        final client = _client(
          (_, _) => ++responses == 1
              ? _reply([_repositoryJson()], etag: '"v1"')
              : _reply(
                  null,
                  status: 304,
                  etag: '"v2"',
                  link: '<https://api.github.com/user/583231/repos?page=2>; rel="next"',
                ),
        );
        await client.repository.getRepositories(_profile);
        final second = await client.repository.getRepositories(_profile);
        final cached = await client.cache.read(
          client.adapter.requests.first.uri.toString(),
        );
        expect(second.repositories.single.id, 1);
        expect(second.nextPage?.queryParameters['page'], '2');
        expect(cached?.etag, '"v2"');
      },
    );

    test('profile and each page retain separate cache keys', () async {
      final client = _client(
        (request, _) => request.uri.path.endsWith('/repos')
            ? _reply([], etag: '"repos"')
            : _reply(_profileJson(), etag: '"profile"'),
      );
      await client.repository.getProfile('octocat');
      await client.repository.getRepositories(_profile);
      await client.repository.getRepositories(
        _profile,
        page: Uri.parse('https://api.github.com/user/583231/repos?page=2'),
      );
      for (final request in client.adapter.requests) {
        expect(request.headers.containsKey('If-None-Match'), false);
      }
      expect(
        (await client.cache.read('https://api.github.com/users/octocat'))?.etag,
        '"profile"',
      );
      expect(
        (await client.cache.read(client.adapter.requests.last.uri.toString()))
            ?.etag,
        '"repos"',
      );
    });

    test('304 without a cached body is rejected', () async {
      final client = _client((_, _) => _reply(null, status: 304));
      await expectLater(
        client.repository.getProfile('octocat'),
        _failure(GitHubFailureKind.invalidResponse),
      );
    });

    test('invalid body never poisons an existing validated entry', () async {
      var responses = 0;
      final cache = _TrackingCache();
      final client = _client(
        (_, _) => ++responses == 1
            ? _reply(_profileJson(), etag: '"valid"')
            : _reply({..._profileJson(), 'id': 'invalid'}, etag: '"invalid"'),
        cache: cache,
      );
      await client.repository.getProfile('octocat');
      await expectLater(
        client.repository.getProfile('octocat'),
        _failure(GitHubFailureKind.invalidResponse),
      );
      expect(cache.writes, hasLength(1));
      expect(
        (await cache.read('https://api.github.com/users/octocat'))?.etag,
        '"valid"',
      );
    });

    test('memory cache isolates instances and serialized body has no mutable alias', () async {
      final cache = MemoryGitHubResponseCache();
      final source = _profileJson();
      await cache.write(
        'key',
        CachedGitHubResponse(body: jsonEncode(source), etag: '"etag"'),
      );
      source['login'] = 'changed';
      expect(jsonDecode((await cache.read('key'))!.body)['login'], 'octocat');
      expect(await MemoryGitHubResponseCache().read('key'), isNull);
    });
  });

  group('GitHub failure taxonomy and rate deadline', () {
    for (final entry in {
      404: GitHubFailureKind.notFound,
      403: GitHubFailureKind.forbidden,
      401: GitHubFailureKind.forbidden,
      500: GitHubFailureKind.server,
      503: GitHubFailureKind.server,
      422: GitHubFailureKind.invalidResponse,
    }.entries) {
      test(
        'HTTP ${entry.key} maps to ${entry.value.name} without retry',
        () async {
          final client = _client(
            (_, _) => _reply({'message': 'Failure'}, status: entry.key),
          );
          await expectLater(
            client.repository.getProfile('octocat'),
            _failure(entry.value),
          );
          expect(client.adapter.requests, hasLength(1));
        },
      );
    }

    for (final entry in {
      DioExceptionType.connectionError: GitHubFailureKind.network,
      DioExceptionType.connectionTimeout: GitHubFailureKind.timeout,
      DioExceptionType.sendTimeout: GitHubFailureKind.timeout,
      DioExceptionType.receiveTimeout: GitHubFailureKind.timeout,
    }.entries) {
      test(
        '${entry.key.name} maps to ${entry.value.name} without retry',
        () async {
          final client = _client(
            (request, _) =>
                throw DioException(requestOptions: request, type: entry.key),
          );
          await expectLater(
            client.repository.getProfile('octocat'),
            _failure(entry.value),
          );
          expect(client.adapter.requests, hasLength(1));
        },
      );
    }

    test(
      'malformed JSON is an invalid response, not a connection failure',
      () async {
        final client = _client(
          (_, _) => ResponseBody.fromString(
            '{invalid',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          ),
        );
        await expectLater(
          client.repository.getProfile('octocat'),
          _failure(GitHubFailureKind.invalidResponse),
        );
      },
    );

    test('wrong top-level repository JSON is rejected', () async {
      final client = _client((_, _) => _reply(_repositoryJson()));
      await expectLater(
        client.repository.getRepositories(_profile),
        _failure(GitHubFailureKind.invalidResponse),
      );
    });

    test(
      '429 honors Retry-After and blocks both endpoints until explicit retry',
      () async {
        var now = DateTime.utc(2026, 10, 3, 12);
        var responses = 0;
        final client = _client(
          (_, _) => ++responses == 1
              ? _reply(
                  {'message': 'Too many requests'},
                  status: 429,
                  headers: {
                    'retry-after': ['20'],
                  },
                )
              : _reply(_profileJson()),
          clock: () => now,
        );
        final deadline = now.add(const Duration(seconds: 20));
        await expectLater(
          client.repository.getProfile('octocat'),
          _rateFailure(deadline),
        );
        await expectLater(
          client.repository.getRepositories(_profile),
          _rateFailure(deadline),
        );
        await expectLater(
          client.repository.getProfile('octocat'),
          _rateFailure(deadline),
        );
        expect(client.adapter.requests, hasLength(1));
        now = deadline;
        expect(
          (await client.repository.getProfile('octocat')).login,
          'octocat',
        );
        expect(client.adapter.requests, hasLength(2));
      },
    );

    test('403 primary rate limit uses the UTC reset epoch', () async {
      final now = DateTime.utc(2026, 10, 3);
      final deadline = now.add(const Duration(minutes: 30));
      final client = _client(
        (_, _) => _reply(
          {'message': 'API rate limit exceeded'},
          status: 403,
          headers: {
            'x-ratelimit-remaining': ['0'],
            'x-ratelimit-reset': ['${deadline.millisecondsSinceEpoch ~/ 1000}'],
          },
        ),
        clock: () => now,
      );
      await expectLater(
        client.repository.getProfile('octocat'),
        _rateFailure(deadline),
      );
    });

    test('secondary rate limit and invalid numeric headers wait at least one minute', () async {
      final now = DateTime.utc(2026, 10, 3);
      for (final headers in <Map<String, List<String>>>[
        {},
        {
          'retry-after': ['not-seconds'],
        },
        {
          'retry-after': ['9999999999999999999'],
        },
        {
          'x-ratelimit-remaining': ['0'],
          'x-ratelimit-reset': ['9999999999999999999'],
        },
      ]) {
        final client = _client(
          (_, _) => _reply(
            {'message': 'You have exceeded a secondary rate limit.'},
            status: 403,
            headers: headers,
          ),
          clock: () => now,
        );
        await expectLater(
          client.repository.getProfile('octocat'),
          _rateFailure(now.add(const Duration(minutes: 1))),
        );
      }
    });
  });

  group('Transport cancellation', () {
    test(
      'cancels pending Dio request and a fresh generation can complete',
      () async {
        final started = Completer<void>();
        final cancelled = Completer<void>();
        final pending = Completer<ResponseBody>();
        final cache = _TrackingCache();
        var responses = 0;
        final client = _client((_, cancelFuture) {
          if (++responses != 1) return _reply(_profileJson());
          started.complete();
          cancelFuture!.then((_) => cancelled.complete());
          return pending.future;
        }, cache: cache);
        final first = client.repository.getProfile('octocat');
        final firstFailure = expectLater(
          first,
          _failure(GitHubFailureKind.cancelled),
        );
        await started.future;
        client.repository.cancelRequests();
        await firstFailure;
        await cancelled.future;
        expect(cache.writes, isEmpty);
        expect((await client.repository.getProfile('octocat')).id, 583231);
        pending.complete(_reply(_profileJson()));
      },
    );

    test('cancellation while awaiting cache does not start a stale network request', () async {
      final cache = _DelayedReadCache();
      final client = _client((_, _) => _reply(_profileJson()), cache: cache);
      final first = client.repository.getProfile('octocat');
      final firstFailure = expectLater(
        first,
        _failure(GitHubFailureKind.cancelled),
      );
      await cache.started.future;
      client.repository.cancelRequests();
      cache.result.complete(null);
      await firstFailure;
      expect(client.adapter.requests, isEmpty);
    });
  });
}

const _profile = GitHubProfile(
  id: 583231,
  login: 'octocat',
  htmlUrl: 'https://github.com/octocat',
  publicRepositories: 8,
);

Map<String, dynamic> _profileJson() => {
  'id': 583231,
  'login': 'octocat',
  'name': null,
  'bio': null,
  'location': null,
  'html_url': 'https://github.com/octocat',
  'avatar_url': 'https://avatars.githubusercontent.com/u/583231?v=4',
  'public_repos': 8,
};

Map<String, dynamic> _repositoryJson({int id = 1}) => {
  'id': id,
  'name': 'Hello-World',
  'full_name': 'octocat/Hello-World',
  'description': null,
  'html_url': 'https://github.com/octocat/Hello-World',
  'language': null,
  'stargazers_count': 12,
  'forks_count': 3,
  'fork': false,
  'archived': false,
  'updated_at': '2026-10-02T12:30:00Z',
};

Matcher _failure(GitHubFailureKind kind) =>
    throwsA(isA<GitHubFailure>().having((error) => error.kind, 'kind', kind));

Matcher _rateFailure(DateTime deadline) => throwsA(
  isA<GitHubFailure>()
      .having((error) => error.kind, 'kind', GitHubFailureKind.rateLimited)
      .having((error) => error.retryAt, 'retryAt', deadline),
);

ResponseBody _reply(
  Object? body, {
  int status = 200,
  String? etag,
  String? link,
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
    if (etag != null) 'etag': [etag],
    if (link != null) 'link': [link],
    ...headers,
  },
);

({
  DioGitHubImportRepository repository,
  _Adapter adapter,
  GitHubResponseCache cache,
})
_client(
  FutureOr<ResponseBody> Function(RequestOptions, Future<void>?) respond, {
  GitHubResponseCache? cache,
  DateTime Function()? clock,
}) {
  final adapter = _Adapter(respond);
  final dio = Dio()..httpClientAdapter = adapter;
  final responseCache = cache ?? MemoryGitHubResponseCache();
  addTearDown(() => dio.close(force: true));
  return (
    repository: DioGitHubImportRepository(
      dio,
      cache: responseCache,
      clock: clock,
    ),
    adapter: adapter,
    cache: responseCache,
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

final class _TrackingCache implements GitHubResponseCache {
  final _memory = MemoryGitHubResponseCache();
  final writes = <String>[];

  @override
  Future<CachedGitHubResponse?> read(String key) => _memory.read(key);

  @override
  Future<void> write(String key, CachedGitHubResponse response) async {
    writes.add(key);
    await _memory.write(key, response);
  }
}

final class _DelayedReadCache implements GitHubResponseCache {
  final started = Completer<void>();
  final result = Completer<CachedGitHubResponse?>();

  @override
  Future<CachedGitHubResponse?> read(String key) {
    started.complete();
    return result.future;
  }

  @override
  Future<void> write(String key, CachedGitHubResponse response) async {}
}
