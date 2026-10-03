import 'portfolio_draft.dart';

abstract interface class PortfolioDraftRepository {
  Future<PortfolioDraft?> read();
  Future<PortfolioDraft> saveNotes(String notes);
}

enum PortfolioDraftFailureKind { unavailable, corrupted, unsupportedVersion }

final class PortfolioDraftFailure implements Exception {
  const PortfolioDraftFailure(this.kind);

  final PortfolioDraftFailureKind kind;
}
