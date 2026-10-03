import '../domain/portfolio_draft.dart';
import '../domain/portfolio_draft_repository.dart';

/// Источник для тестов и isolated app DI; production подставляет Hive в bootstrap.
final class MemoryPortfolioDraftRepository implements PortfolioDraftRepository {
  MemoryPortfolioDraftRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  PortfolioDraft? _draft;

  @override
  Future<PortfolioDraft?> read() async => _draft;

  @override
  Future<PortfolioDraft> saveNotes(String notes) async {
    final draft = PortfolioDraft(
      notes: notes,
      revision: (_draft?.revision ?? 0) + 1,
      updatedAt: _clock(),
      pendingSync: true,
    );
    _draft = draft;
    return draft;
  }
}
