import 'github_failure.dart';

/// Происхождение снимка и доступность его offline-копии без storage/HTTP SDK.
final class GitHubReadMetadata {
  const GitHubReadMetadata({
    this.fromCache = false,
    this.validatedAt,
    this.fallbackFailure,
    this.cacheWriteFailed = false,
    this.cacheUnavailable = false,
  });

  final bool fromCache;
  final DateTime? validatedAt;
  final GitHubFailure? fallbackFailure;
  final bool cacheWriteFailed;
  final bool cacheUnavailable;
}

/// Смешанный снимок остаётся stale, пока refresh не заменит его целиком.
GitHubReadMetadata combineGitHubReadMetadata(
  Iterable<GitHubReadMetadata> sources,
) {
  DateTime? oldest;
  GitHubFailure? fallbackFailure;
  var fromCache = false;
  var cacheWriteFailed = false;
  var cacheUnavailable = false;
  for (final source in sources) {
    final validatedAt = source.validatedAt;
    if (validatedAt != null &&
        (oldest == null || validatedAt.isBefore(oldest))) {
      oldest = validatedAt;
    }
    fallbackFailure ??= source.fallbackFailure;
    fromCache |= source.fromCache;
    cacheWriteFailed |= source.cacheWriteFailed;
    cacheUnavailable |= source.cacheUnavailable;
  }
  return GitHubReadMetadata(
    fromCache: fromCache,
    validatedAt: oldest,
    fallbackFailure: fallbackFailure,
    cacheWriteFailed: cacheWriteFailed,
    cacheUnavailable: cacheUnavailable,
  );
}
