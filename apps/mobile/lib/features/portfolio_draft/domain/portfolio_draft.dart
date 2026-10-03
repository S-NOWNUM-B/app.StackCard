/// Предварительные заметки к портфолио; полный Builder появится отдельно.
final class PortfolioDraft {
  PortfolioDraft({
    required this.notes,
    required this.revision,
    required DateTime? updatedAt,
    required this.pendingSync,
  }) : updatedAt = updatedAt?.toUtc() {
    if (revision < 0) throw RangeError.value(revision, 'revision');
  }

  final String notes;
  final int revision;
  final DateTime? updatedAt;
  final bool pendingSync;
}
