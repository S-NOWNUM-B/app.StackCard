import '../domain/portfolio_draft.dart';
import '../domain/portfolio_draft_repository.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_validation.dart';

/// Источник для тестов и isolated app DI; production подставляет Hive в bootstrap.
final class MemoryPortfolioDraftRepository implements PortfolioDraftRepository {
  MemoryPortfolioDraftRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  PortfolioDraft? _draft;

  @override
  Future<PortfolioDraft?> read() async => _draft;

  @override
  Future<PortfolioDraft> saveNotes(String notes) async =>
      _write(notes, _draft?.content);

  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async {
    if ((_draft?.revision ?? 0) != expectedRevision) {
      throw const PortfolioDraftFailure(PortfolioDraftFailureKind.conflict);
    }
    if (validatePortfolioContent(content).isNotEmpty) {
      throw const PortfolioDraftFailure(
        PortfolioDraftFailureKind.invalidContent,
      );
    }
    return _write(notes, content);
  }

  PortfolioDraft _write(String notes, PortfolioContent? content) {
    final draft = PortfolioDraft(
      notes: notes,
      revision: (_draft?.revision ?? 0) + 1,
      updatedAt: _clock(),
      pendingSync: true,
      content: content,
    );
    _draft = draft;
    return draft;
  }
}
