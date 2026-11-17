import '../domain/portfolio_content.dart';
import '../domain/portfolio_history.dart';

/// Превью и тесты без диска; ограничения те же, что у Hive.
final class MemoryPortfolioHistoryRepository
    implements PortfolioHistoryRepository {
  List<PortfolioSnapshot> _items = const [];
  int _counter = 0;

  @override
  Future<List<PortfolioSnapshot>> list() async => _items;

  @override
  Future<void> record(PortfolioContent workspace, DateTime at) async {
    final snapshot = buildPortfolioSnapshot(
      workspace: workspace,
      at: at,
      id: '${at.toUtc().microsecondsSinceEpoch}-${_counter++}',
    );
    if (snapshot != null) _items = appendPortfolioSnapshot(_items, snapshot);
  }

  @override
  Future<void> clear() async => _items = const [];
}
