/// Сериализованный ответ и HTTP validators; body не разделяет mutable JSON.
final class CachedGitHubResponse {
  const CachedGitHubResponse({
    required this.body,
    this.etag,
    this.link,
    this.validatedAt,
  });

  final String body;
  final String? etag;
  final String? link;
  final DateTime? validatedAt;
}

const githubCacheMaxAge = Duration(days: 7);

/// Реализация определяет storage; repo отвечает за DTO и безопасные next links.
abstract interface class GitHubResponseCache {
  Future<CachedGitHubResponse?> read(String key);
  Future<void> write(String key, CachedGitHubResponse response);
}

/// Очистка необязательна для сторонних cache adapters с read/write контрактом.
abstract interface class EvictableGitHubResponseCache
    implements GitHubResponseCache {
  Future<void> remove(String key);
}

final class MemoryGitHubResponseCache implements EvictableGitHubResponseCache {
  final _responses = <String, CachedGitHubResponse>{};

  @override
  Future<CachedGitHubResponse?> read(String key) async => _responses[key];

  @override
  Future<void> write(String key, CachedGitHubResponse response) async {
    _responses[key] = response;
  }

  @override
  Future<void> remove(String key) async => _responses.remove(key);
}
