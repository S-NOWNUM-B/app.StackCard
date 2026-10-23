import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_stackcard/features/github_import/data/dio_github_import_repository.dart';
import 'package:app_stackcard/features/github_import/data/hive_github_response_cache.dart';
import 'package:app_stackcard/features/github_import/domain/github_failure.dart';
import 'package:app_stackcard/features/github_import/domain/github_profile.dart';
import 'package:app_stackcard/features/github_import/domain/github_read_metadata.dart';
import 'package:app_stackcard/features/github_import/domain/github_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_github_sync.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_validation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:hive/hive.dart';

import 'fixture.dart';

/// Явный host-run: настоящая публичная сеть и отдельный временный Hive.
/// `dart run tool/performance/github_network.dart output.json github-login`
Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    throw ArgumentError('Укажите путь evidence JSON');
  }
  final output = File(arguments[0]).absolute;
  final username = arguments.length > 1 ? arguments[1] : 'dart-lang';
  final directory = await Directory.systemTemp.createTemp('stackcard-gh-live-');
  final requests = <Map<String, Object?>>[];
  final adapter = _ObservedAdapter(requests);
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: false,
    ),
  )..httpClientAdapter = adapter;
  final result = <String, Object?>{
    'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'environment': {
      'runtime': Platform.version,
      'os': Platform.operatingSystem,
      'mode':
          'Dart VM host CLI; actual GitHub REST + production DTO/cache code',
      'credentials': 'none; request header allowlist; no user account/session',
      'storage': 'disposable temporary directory; ordinary app data untouched',
      'command':
          '${Platform.resolvedExecutable} ${Platform.script.toFilePath()} ${arguments.join(' ')}',
    },
    'account': username,
    'requests': requests,
    'stages': <String, Object?>{},
    'limitations': [
      'Host wall-clock includes response observation/JSON/Hive; not Android frames or retained heap.',
      'Offline is a deliberate transport failure, not a physical network disconnect.',
      'Unauthenticated public API cannot inspect private repositories.',
      'A real HTTP 304 is claimed only if observed in request status; upstream may return 200.',
      'No UI pagination, publication, UID transition or device acceptance is implied.',
    ],
  };
  final stages = result['stages']! as Map<String, Object?>;
  try {
    result['source'] = await _sourceMetadata();
    Hive.init(directory.path);
    var box = await Hive.openBox<dynamic>('github_http_v1');
    var draftBox = await Hive.openBox<dynamic>('portfolio_draft_accounts');
    await HivePortfolioDraftRepository(draftBox).save(
      performanceWorkspace(),
      expectedRevision: 0,
      notes: 'SYNTHETIC_PRIVATE_NOTES_DO_NOT_EXPORT',
    );
    await draftBox.flush();
    final originalDraft = draftBox.get(HivePortfolioDraftRepository.storageKey);
    _check(originalDraft is String, 'Synthetic draft was persisted');
    var cache = HiveGitHubResponseCache(box);
    var repository = DioGitHubImportRepository(dio, cache: cache);

    adapter.stage = 'cold-online-pagination';
    final coldWatch = Stopwatch()..start();
    final profile = await repository.getProfile(username);
    final pageUris = <Uri>[];
    final ids = <int>{};
    final realRepositories = <GitHubRepository>[];
    final pages = <Map<String, Object?>>[];
    Uri? pageUri;
    do {
      final page = await repository.getRepositories(profile, page: pageUri);
      _check(!page.readMetadata.fromCache, 'Cold page came from network');
      final actualUri = Uri.parse(requests.last['uri']! as String);
      pageUris.add(actualUri);
      for (final item in page.repositories) {
        _check(ids.add(item.id), 'No duplicate repository IDs between pages');
        realRepositories.add(item);
      }
      pages.add({
        'uri': actualUri.toString(),
        'count': page.repositories.length,
        'repositoryIds': page.repositories.map((item) => item.id).toList(),
        'nextPage': page.nextPage?.toString(),
        'metadata': _metadata(page.readMetadata),
      });
      pageUri = page.nextPage;
      _check(pages.length <= 30, 'Bounded public pagination');
    } while (pageUri != null);
    coldWatch.stop();
    _check(pages.length >= 2, 'Real account provided more than one page');
    _check(ids.isNotEmpty, 'Real repositories were returned');
    stages['coldOnline'] = {
      'elapsedMs': coldWatch.elapsedMicroseconds / 1000,
      'profileId': profile.id,
      'profileLogin': profile.login,
      'profilePublicRepositories': profile.publicRepositories,
      'pages': pages,
      'uniqueRepositories': ids.length,
      'totalMatchesProfileCount': ids.length == profile.publicRepositories,
    };
    final workspace = _publicSourceWorkspace(profile, realRepositories);
    final exported = File('${output.path}.workspace.json');
    final exportedJson = jsonEncode(encodePortfolioContent(workspace));
    _check(
      !exportedJson.contains('SYNTHETIC_PRIVATE') &&
          !exportedJson.contains('LEGACY_PRIVATE') &&
          !exportedJson.contains('"notes"'),
      'Export has only public source data and generated presentation structure',
    );
    await exported.parent.create(recursive: true);
    await exported.writeAsString('$exportedJson\n');
    final exportedHash = await Process.run('/usr/bin/shasum', [
      '-a',
      '256',
      exported.path,
    ]);
    _check(exportedHash.exitCode == 0, 'Exported workspace SHA256 available');
    result['exportedWorkspace'] = {
      'path': exported.path,
      'sha256': (exportedHash.stdout as String).split(RegExp(r'\s+')).first,
      'utf8Bytes': await exported.length(),
      'publicProfile': profile.htmlUrl,
      'projects': workspace.projects.length,
      'mainAttachments': mainPortfolioDocument(workspace)!.projects.length,
      'source': 'Actual profile and complete repositories from the cold-online run; domain addGitHubProject matches the importSelected loop',
      'syntheticContent': 'none; IDs/document title/timestamps/attachment selection are generated presentation structure',
      'notesIncluded': false,
      'privateIsolationFixtureIncluded': false,
      'browserAvatarLimitation': 'Existing web benchmark explicitly supplies local demo-portrait bytes instead of GitHub profile avatar',
    };
    await box.flush();
    final beforeReopen = _entries(box);
    final rawBeforeReopen = _rawSnapshot(box);
    final profileUri = Uri.https('api.github.com', '/users/$username');
    final profileCachedBefore = await cache.read(profileUri.toString());
    _check(profileCachedBefore != null, 'Network profile persisted');

    final reopenWatch = Stopwatch()..start();
    await Hive.close();
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('github_http_v1');
    draftBox = await Hive.openBox<dynamic>('portfolio_draft_accounts');
    cache = HiveGitHubResponseCache(box);
    repository = DioGitHubImportRepository(dio, cache: cache);
    _check(
      _rawSnapshot(box) == rawBeforeReopen,
      'Hive reopen preserved every raw cache envelope',
    );
    _check(
      draftBox.get(HivePortfolioDraftRepository.storageKey) == originalDraft,
      'Hive reopen preserved exact private draft bytes',
    );
    reopenWatch.stop();
    stages['persistentReopen'] = {
      'elapsedMs': reopenWatch.elapsedMicroseconds / 1000,
      'entries': beforeReopen,
      'allEnvelopesIdentical': true,
      'draftBytesIdentical': true,
    };

    adapter.stage = 'offline-injected-transport-failure';
    adapter.offline = true;
    final offlineWatch = Stopwatch()..start();
    final offlineProfile = await repository.getProfile(username);
    _checkFallback(offlineProfile.readMetadata);
    final offlineIds = <int>{};
    for (final uri in pageUris) {
      final page = await repository.getRepositories(offlineProfile, page: uri);
      _checkFallback(page.readMetadata);
      offlineIds.addAll(page.repositories.map((item) => item.id));
    }
    _check(
      offlineIds.length == ids.length && offlineIds.containsAll(ids),
      'Offline copy contains the complete online ID set',
    );
    _check(
      _rawSnapshot(box) == rawBeforeReopen,
      'Offline fallback did not renew timestamps or mutate body',
    );
    offlineWatch.stop();
    stages['offlineFallback'] = {
      'failureInjection':
          'HttpClientAdapter throws DioException.connectionError before IO',
      'elapsedMs': offlineWatch.elapsedMicroseconds / 1000,
      'uniqueRepositories': offlineIds.length,
      'sameRepositoryIds': true,
      'cacheBytesAndTimestampsIdentical': true,
      'profileMetadata': _metadata(offlineProfile.readMetadata),
    };

    adapter.stage = 'reconnect-conditional';
    adapter.offline = false;
    final reconnectWatch = Stopwatch()..start();
    final refreshedProfile = await repository.getProfile(username);
    _check(
      !refreshedProfile.readMetadata.fromCache,
      'Reconnect verified profile online',
    );
    final reconnectPages = <Map<String, Object?>>[];
    for (final uri in pageUris) {
      final refreshed = await repository.getRepositories(
        refreshedProfile,
        page: uri,
      );
      _check(
        !refreshed.readMetadata.fromCache,
        'Reconnect verified page online',
      );
      reconnectPages.add({
        'uri': uri.toString(),
        'count': refreshed.repositories.length,
        'metadata': _metadata(refreshed.readMetadata),
      });
    }
    reconnectWatch.stop();
    final conditional = requests
        .where((item) => item['stage'] == adapter.stage)
        .toList();
    _check(
      conditional.every(
        (item) => (item['requestHeaders']! as Map).containsKey('if-none-match'),
      ),
      'Persisted ETag was sent on each reconnect request',
    );
    final observed304 = conditional
        .where((item) => item['status'] == 304)
        .length;
    stages['reconnectConditional'] = {
      'elapsedMs': reconnectWatch.elapsedMicroseconds / 1000,
      'requests': conditional.length,
      'ifNoneMatchSentForAll': true,
      'observed304Responses': observed304,
      'observed200Responses': conditional
          .where((item) => item['status'] == 200)
          .length,
      'pages': reconnectPages,
    };

    await box.put('harness-corrupt-entry', '{invalid JSON');
    _check(
      await cache.read('harness-corrupt-entry') == null,
      'Corrupt entry removed safely',
    );
    await cache.clear();
    _check(box.isEmpty, 'Public cache clear persisted');
    await Hive.close();
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('github_http_v1');
    draftBox = await Hive.openBox<dynamic>('portfolio_draft_accounts');
    _check(box.isEmpty, 'Cache stayed empty after reopen');
    _check(
      draftBox.get(HivePortfolioDraftRepository.storageKey) == originalDraft,
      'Cache lifecycle preserved exact draft bytes',
    );
    final retained = await HivePortfolioDraftRepository(draftBox).read();
    _check(
      retained?.revision == 1 &&
          retained?.notes == 'SYNTHETIC_PRIVATE_NOTES_DO_NOT_EXPORT',
      'Actual draft repository decodes preserved content',
    );
    stages['draftIsolation'] = {
      'fixture': 'Synthetic valid aggregate: 200 projects, main +20 legacy documents, private notes',
      'draftEnvelopeUtf8Bytes': utf8.encode(originalDraft as String).length,
      'exactEnvelopePreserved': true,
      'repositoryReadRevision': retained?.revision,
      'corruptCacheEntryEvicted': true,
      'cacheClearAndReopenEmpty': true,
    };
    result['status'] = 'passed';
  } catch (error) {
    result['status'] = 'failed';
    result['failure'] = error is GitHubFailure
        ? {'kind': error.kind.name, 'retryAt': error.retryAt?.toIso8601String()}
        : error.toString();
    exitCode = 1;
  } finally {
    dio.close(force: true);
    await Hive.close();
    await directory.delete(recursive: true);
    result['finishedAtUtc'] = DateTime.now().toUtc().toIso8601String();
    await output.parent.create(recursive: true);
    await output.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(result)}\n',
    );
    stdout.writeln('GitHub network ${result['status']}: ${output.path}');
  }
}

void _check(bool condition, String reason) {
  if (!condition) throw StateError(reason);
}

PortfolioContent _publicSourceWorkspace(
  GitHubProfile profile,
  List<GitHubRepository> repositories,
) {
  final date = profile.readMetadata.validatedAt!;
  final base = PortfolioContent(
    githubUsername: profile.login.toLowerCase(),
    profile: PortfolioProfile(
      name: profile.name ?? profile.login,
      bio: profile.bio ?? '',
      locationText: profile.location ?? '',
      publishLocation: true,
      avatarUrl: profile.avatarUrl ?? '',
    ),
    links: [
      SocialLink(
        id: 'github-public-profile',
        kind: SocialLinkKind.github,
        label: 'GitHub',
        url: profile.htmlUrl,
        publishAllowed: true,
      ),
    ],
  );
  var workspace = base;
  // Тот же pure domain импорт, что в importSelectedGitHubRepositories.
  for (final repository in repositories) {
    workspace = addGitHubProject(
      workspace,
      GitHubProjectSource(
        repositoryId: repository.id,
        name: repository.name,
        fullName: repository.fullName,
        htmlUrl: repository.htmlUrl,
        description: repository.description,
        language: repository.language,
        stars: repository.stars,
        forks: repository.forks,
        isFork: repository.isFork,
        archived: repository.archived,
        updatedAt: repository.updatedAt,
      ),
      validatedAt: date,
    );
  }
  final main = PortfolioDocument(
    id: 'github-public-main',
    title: profile.name ?? profile.login,
    kind: PortfolioDocumentKind.portfolio,
    createdAt: date,
    updatedAt: date,
    content: seedDocumentContent(base)
        .copyWith(blocks: mainPortfolioBlocks(base)),
    projects: workspace.projects
        .map((project) => PortfolioProjectAttachment(projectId: project.id))
        .toList(),
  );
  workspace = workspace.copyWith(mainPortfolioId: main.id, documents: [main]);
  _check(
    validatePortfolioContent(workspace).isEmpty,
    'Real public source workspace passes the production domain validator',
  );
  return workspace;
}

void _checkFallback(GitHubReadMetadata metadata) {
  _check(
    metadata.fromCache &&
        metadata.fallbackFailure?.kind == GitHubFailureKind.network &&
        metadata.validatedAt != null,
    'Explicit cache provenance after injected network failure',
  );
}

Map<String, Object?> _metadata(GitHubReadMetadata metadata) => {
  'fromCache': metadata.fromCache,
  'validatedAtUtc': metadata.validatedAt?.toIso8601String(),
  'fallbackFailure': metadata.fallbackFailure?.kind.name,
  'cacheUnavailable': metadata.cacheUnavailable,
  'cacheWriteFailed': metadata.cacheWriteFailed,
};

List<Map<String, Object?>> _entries(Box<dynamic> box) {
  final keys = box.keys.cast<String>().toList()..sort();
  return keys.map((key) {
    final raw = box.get(key) as String;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return <String, Object?>{
      'uri': key,
      'envelopeUtf8Bytes': utf8.encode(raw).length,
      'bodyUtf8Bytes': utf8.encode(decoded['body'] as String).length,
      'etag': decoded['etag'],
      'link': decoded['link'],
      'validatedAt': decoded['validatedAt'],
    };
  }).toList();
}

String _rawSnapshot(Box<dynamic> box) {
  final keys = box.keys.cast<String>().toList()..sort();
  return jsonEncode({for (final key in keys) key: box.get(key)});
}

Future<Map<String, Object?>> _sourceMetadata() async {
  final paths = [
    'tool/performance/github_network.dart',
    'tool/performance/fixture.dart',
    'lib/features/github_import/data/dio_github_import_repository.dart',
    'lib/features/github_import/data/github_profile_dto.dart',
    'lib/features/github_import/data/github_repository_dto.dart',
    'lib/features/github_import/data/github_response_cache.dart',
    'lib/features/github_import/data/hive_github_response_cache.dart',
    'lib/features/portfolio_draft/data/hive_portfolio_draft_repository.dart',
    'lib/features/portfolio_draft/data/portfolio_content_codec.dart',
    'lib/features/portfolio_draft/domain/portfolio_github_sync.dart',
    'pubspec.yaml',
    'pubspec.lock',
  ];
  final hashes = <String, String>{};
  for (final path in paths) {
    final hash = await Process.run('/usr/bin/shasum', ['-a', '256', path]);
    _check(hash.exitCode == 0, 'Source hash available: $path');
    hashes[path] = (hash.stdout as String).split(RegExp(r'\s+')).first;
  }
  final head = await Process.run('git', ['rev-parse', 'HEAD']);
  final branch = await Process.run('git', ['branch', '--show-current']);
  return {
    'gitHead': (head.stdout as String).trim(),
    'branch': (branch.stdout as String).trim(),
    'workingTree': 'Existing uncommitted work preserved; SHA256 identifies actual run sources',
    'sha256': hashes,
    'dio': '5.11.1',
    'hive': '2.2.3',
  };
}

final class _ObservedAdapter implements HttpClientAdapter {
  _ObservedAdapter(this.requests);

  final List<Map<String, Object?>> requests;
  final _delegate = IOHttpClientAdapter();
  String stage = '';
  bool offline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final watch = Stopwatch()..start();
    final headers = <String, Object?>{};
    for (final entry in options.headers.entries) {
      final name = entry.key.toLowerCase();
      _check(
        !{'authorization', 'cookie', 'proxy-authorization'}.contains(name),
        'No credentials permitted in harness',
      );
      if ({
        'accept',
        'x-github-api-version',
        'user-agent',
        'if-none-match',
      }.contains(name)) {
        headers[name] = entry.value;
      }
    }
    final record = <String, Object?>{
      'stage': stage,
      'uri': options.uri.toString(),
      'method': options.method,
      'requestHeaders': headers,
      'transport': offline ? 'injected-offline-failure' : 'real-dart-io-https',
    };
    requests.add(record);
    try {
      if (offline) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'Explicit acceptance harness offline injection',
        );
      }
      final response = await _delegate.fetch(
        options,
        requestStream,
        cancelFuture,
      );
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        bytes.add(chunk);
      }
      final body = bytes.takeBytes();
      if (response.statusCode == 200 && options.uri.path.endsWith('/repos')) {
        final repositories = jsonDecode(utf8.decode(body)) as List;
        _check(
          repositories.every((item) => (item as Map)['private'] == false),
          'Every received repository is explicitly public',
        );
        record['publicRepositories'] = repositories.length;
      }
      record.addAll({
        'status': response.statusCode,
        'decodedResponseBodyBytes': body.length,
        'responseHeaders': {
          for (final name in [
            'etag',
            'link',
            'x-ratelimit-limit',
            'x-ratelimit-remaining',
            'x-ratelimit-reset',
            'x-github-api-version-selected',
            'date',
            'content-length',
          ])
            if (response.headers[name] != null)
              name: response.headers[name]!.join(','),
        },
      });
      return ResponseBody.fromBytes(
        body,
        response.statusCode,
        headers: response.headers,
        statusMessage: response.statusMessage,
      );
    } on DioException catch (error) {
      record['failureType'] = error.type.name;
      rethrow;
    } finally {
      record['elapsedMs'] = watch.elapsedMicroseconds / 1000;
    }
  }

  @override
  void close({bool force = false}) => _delegate.close(force: force);
}
