/// Сериализованный ответ и HTTP validators; body не разделяет mutable JSON.
final class CachedGitHubResponse {
  const CachedGitHubResponse({required this.body, this.etag, this.link});

  final String body;
  final String? etag;
  final String? link;
}

/// Сейчас используется только session memory; persistence относится к Phase 5.
abstract interface class GitHubResponseCache {
  Future<CachedGitHubResponse?> read(String key);
  Future<void> write(String key, CachedGitHubResponse response);
}

final class MemoryGitHubResponseCache implements GitHubResponseCache {
  final _responses = <String, CachedGitHubResponse>{};

  @override
  Future<CachedGitHubResponse?> read(String key) async => _responses[key];

  @override
  Future<void> write(String key, CachedGitHubResponse response) async {
    _responses[key] = response;
  }
}
