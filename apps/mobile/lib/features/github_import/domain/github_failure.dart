enum GitHubFailureKind {
  invalidUsername,
  notFound,
  network,
  timeout,
  rateLimited,
  forbidden,
  server,
  invalidResponse,
  cancelled,
}

/// Ошибка источника без HTTP SDK и внутренних сообщений сервера.
final class GitHubFailure implements Exception {
  const GitHubFailure(this.kind, {this.retryAt});

  final GitHubFailureKind kind;
  final DateTime? retryAt;
}
