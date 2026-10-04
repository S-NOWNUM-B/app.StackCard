import 'portfolio_content.dart';

enum PortfolioPublicationFailureKind {
  invalidUsername,
  usernameUnavailable,
  invalidContent,
  invalidRemoteState,
}

final class PortfolioPublicationFailure implements Exception {
  const PortfolioPublicationFailure(this.kind);
  final PortfolioPublicationFailureKind kind;
}

/// Prepared for an explicit publication action; synchronization never calls it.
abstract interface class PortfolioPublicationRepository {
  Future<void> publish({
    required String username,
    required PortfolioContent content,
  });
  Future<void> unpublish();
}
