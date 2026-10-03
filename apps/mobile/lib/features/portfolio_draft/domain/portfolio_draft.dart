import 'portfolio_content.dart';

/// Private notes и optional Builder content одного локального draft.
final class PortfolioDraft {
  PortfolioDraft({
    required this.notes,
    required this.revision,
    required DateTime? updatedAt,
    required this.pendingSync,
    this.content,
  }) : updatedAt = updatedAt?.toUtc() {
    if (revision < 0) throw RangeError.value(revision, 'revision');
  }

  final String notes;
  final int revision;
  final DateTime? updatedAt;
  final bool pendingSync;
  final PortfolioContent? content;
}
