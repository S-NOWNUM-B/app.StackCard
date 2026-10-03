import 'portfolio_draft.dart';
import 'portfolio_content.dart';

abstract interface class PortfolioDraftRepository {
  Future<PortfolioDraft?> read();
  Future<PortfolioDraft> saveNotes(String notes);
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  });
}

enum PortfolioDraftFailureKind {
  unavailable,
  corrupted,
  unsupportedVersion,
  conflict,
  invalidContent,
}

final class PortfolioDraftFailure implements Exception {
  const PortfolioDraftFailure(this.kind);

  final PortfolioDraftFailureKind kind;
}
