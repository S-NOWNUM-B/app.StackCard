import 'dart:convert';

import 'package:dio/dio.dart';

import '../domain/github_failure.dart';
import '../domain/github_filters.dart';
import '../domain/github_import_repository.dart';
import '../domain/github_profile.dart';
import '../domain/github_repository.dart';
import 'github_profile_dto.dart';
import 'github_repository_dto.dart';
import 'github_response_cache.dart';

final class DioGitHubImportRepository implements GitHubImportRepository {
  DioGitHubImportRepository(
    this._dio, {
    required this._cache,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Dio _dio;
  final GitHubResponseCache _cache;
  final DateTime Function() _clock;
  final _tokens = <CancelToken>{};
  DateTime? _blockedUntil;
  int _generation = 0;

  @override
  void cancelRequests() {
    _generation++;
    for (final token in _tokens) {
      token.cancel('Сценарий заменён');
    }
    _tokens.clear();
  }

  @override
  Future<GitHubProfile> getProfile(String username) async {
    final normalized = normalizeGitHubUsername(username);
    if (validateGitHubUsername(normalized) != null) {
      throw const GitHubFailure(GitHubFailureKind.invalidUsername);
    }
    return _read(
      Uri.https('api.github.com', '/users/$normalized'),
      (body, _) => GitHubProfileDto.fromJson(body).profile,
    );
  }

  @override
  Future<GitHubRepositoriesPage> getRepositories(
    GitHubProfile profile, {
    Uri? page,
  }) async {
    if (profile.id <= 0 ||
        profile.login != profile.login.trim() ||
        validateGitHubUsername(profile.login) != null) {
      throw const GitHubFailure(GitHubFailureKind.invalidResponse);
    }
    final uri =
        page ??
        Uri.https('api.github.com', '/users/${profile.login}/repos', {
          'type': 'owner',
          'sort': 'updated',
          'direction': 'desc',
          'per_page': '30',
        });
    _verifyPage(uri, profile);
    return _read(uri, (body, link) {
      if (body is! List) throw const FormatException('Ожидался JSON array');
      final next = _nextPage(link);
      if (next != null) _verifyPage(next, profile);
      return GitHubRepositoriesPage(
        repositories: body.map(
          (item) => GitHubRepositoryDto.fromJson(item).repository,
        ),
        nextPage: next,
      );
    });
  }

  void _verifyPage(Uri uri, GitHubProfile profile) {
    final allowedPaths = {
      '/users/${profile.login.toLowerCase()}/repos',
      '/user/${profile.id}/repos',
    };
    if (uri.scheme != 'https' ||
        uri.host != 'api.github.com' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !allowedPaths.contains(uri.path.toLowerCase())) {
      throw const GitHubFailure(GitHubFailureKind.invalidResponse);
    }
  }

  Uri? _nextPage(String? link) {
    if (link == null) return null;
    for (final part in link.split(',')) {
      final match = RegExp(r'^\s*<([^>]+)>\s*;\s*rel="([^"]+)"')
          .firstMatch(part);
      if (match == null) {
        throw const GitHubFailure(GitHubFailureKind.invalidResponse);
      }
      if (match[2]!.split(' ').contains('next')) {
        final uri = Uri.tryParse(match[1]!);
        if (uri == null) {
          throw const GitHubFailure(GitHubFailureKind.invalidResponse);
        }
        return uri;
      }
    }
    return null;
  }

  Future<T> _read<T>(Uri uri, T Function(Object?, String?) parse) async {
    final generation = _generation;
    _ensureAllowed();
    final cached = await _cache.read(uri.toString());
    _ensureCurrent(generation);
    _ensureAllowed();
    final token = CancelToken();
    _tokens.add(token);
    try {
      final response = await _dio.getUri<Object?>(
        uri,
        cancelToken: token,
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2026-03-10',
            'User-Agent': 'StackCard',
            if (cached?.etag != null) 'If-None-Match': cached!.etag,
          },
          followRedirects: false,
          validateStatus: (status) => status == 200 || status == 304,
        ),
      );
      _ensureCurrent(generation);
      final Object? body;
      final String? link;
      if (response.statusCode == 304) {
        if (cached == null) {
          throw const GitHubFailure(GitHubFailureKind.invalidResponse);
        }
        body = jsonDecode(cached.body);
        link = _header(response.headers, 'link') ?? cached.link;
      } else {
        body = response.data;
        link = _header(response.headers, 'link');
      }
      // Проверяем body и pagination до сохранения HTTP validators.
      final value = parse(body, link);
      _ensureCurrent(generation);
      await _cache.write(
        uri.toString(),
        CachedGitHubResponse(
          body: jsonEncode(body),
          etag:
              _header(response.headers, 'etag') ??
              (response.statusCode == 304 ? cached?.etag : null),
          link: link,
        ),
      );
      _ensureCurrent(generation);
      return value;
    } on DioException catch (error) {
      _ensureCurrent(generation);
      throw _failure(error);
    } on FormatException {
      throw const GitHubFailure(GitHubFailureKind.invalidResponse);
    } finally {
      _tokens.remove(token);
    }
  }

  void _ensureAllowed() {
    final blocked = _blockedUntil;
    if (blocked != null && _clock().isBefore(blocked)) {
      throw GitHubFailure(GitHubFailureKind.rateLimited, retryAt: blocked);
    }
  }

  void _ensureCurrent(int generation) {
    if (generation != _generation) {
      throw const GitHubFailure(GitHubFailureKind.cancelled);
    }
  }

  GitHubFailure _failure(DioException error) {
    if (error.type == DioExceptionType.cancel) {
      return const GitHubFailure(GitHubFailureKind.cancelled);
    }
    if ({
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    }.contains(error.type)) {
      return const GitHubFailure(GitHubFailureKind.timeout);
    }
    final response = error.response;
    if (response == null) {
      return GitHubFailure(
        error.error is FormatException
            ? GitHubFailureKind.invalidResponse
            : GitHubFailureKind.network,
      );
    }
    final status = response.statusCode;
    final headers = response.headers;
    final message = response.data is Map
        ? (response.data as Map)['message']
        : null;
    final limited =
        status == 429 ||
        status == 403 &&
            (_header(headers, 'x-ratelimit-remaining') == '0' ||
                _header(headers, 'retry-after') != null ||
                message is String &&
                    message.toLowerCase().contains('rate limit'));
    if (limited) {
      final now = _clock().toUtc();
      final seconds = int.tryParse(_header(headers, 'retry-after') ?? '');
      final reset = int.tryParse(_header(headers, 'x-ratelimit-reset') ?? '');
      // Invalid or overflowing headers fall back to GitHub's one-minute wait.
      const maxEpochSeconds = 8640000000000;
      final retryAt =
          seconds != null &&
              seconds > 0 &&
              seconds < maxEpochSeconds - now.millisecondsSinceEpoch ~/ 1000
          ? now.add(Duration(seconds: seconds))
          : _header(headers, 'x-ratelimit-remaining') == '0' &&
                reset != null &&
                reset > 0 &&
                reset <= maxEpochSeconds
          ? DateTime.fromMillisecondsSinceEpoch(reset * 1000, isUtc: true)
          : now.add(const Duration(minutes: 1));
      final deadline = retryAt.isAfter(now)
          ? retryAt
          : now.add(const Duration(seconds: 1));
      if (_blockedUntil == null || deadline.isAfter(_blockedUntil!)) {
        _blockedUntil = deadline;
      }
      return GitHubFailure(
        GitHubFailureKind.rateLimited,
        retryAt: _blockedUntil,
      );
    }
    return GitHubFailure(switch (status ?? 0) {
      404 => GitHubFailureKind.notFound,
      401 || 403 => GitHubFailureKind.forbidden,
      >= 500 && <= 599 => GitHubFailureKind.server,
      _ => GitHubFailureKind.invalidResponse,
    });
  }

  String? _header(Headers headers, String name) => headers[name]?.join(',');
}
