import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import 'data/memory_portfolio_history_repository.dart';
import 'domain/portfolio_history.dart';

/// Native composition подставляет Hive-репозитории; по умолчанию — память.
final portfolioHistoryRepositoryFactoryProvider =
    Provider<PortfolioHistoryRepository Function(String? uid)>((ref) {
      final repositories = <String?, PortfolioHistoryRepository>{};
      return (uid) =>
          repositories.putIfAbsent(uid, MemoryPortfolioHistoryRepository.new);
    });

/// История привязана к владельцу: UID аккаунта или guest. Пока сессия
/// восстанавливается или недоступна, истории нет (чужая не открывается).
final portfolioHistoryRepositoryProvider =
    Provider<PortfolioHistoryRepository?>((ref) {
      final factory = ref.watch(portfolioHistoryRepositoryFactoryProvider);
      if (ref.watch(accountAuthRepositoryProvider) == null) {
        return factory(null);
      }
      final session = ref.watch(accountSessionProvider);
      if (session.isLoading || session.hasError || !session.hasValue) {
        return null;
      }
      final uid = session.value?.uid;
      if (uid != null) return factory(uid);
      return ref.watch(guestAccessProvider) ? factory(null) : null;
    });

/// Очистка снимков UID при выходе из аккаунта; null — без диска.
final portfolioHistoryCleanupProvider =
    Provider<Future<void> Function(String uid)?>((ref) => null);

/// Восстановление версии: Editor применяет снимок к буферу и не сохраняет.
final mainPortfolioEditorRestoreProvider =
    NotifierProvider<MainPortfolioEditorRestore, PortfolioSnapshot?>(
      MainPortfolioEditorRestore.new,
    );

final class MainPortfolioEditorRestore extends Notifier<PortfolioSnapshot?> {
  @override
  PortfolioSnapshot? build() => null;

  void request(PortfolioSnapshot snapshot) => state = snapshot;
  void consume() => state = null;
}

/// Список снимков владельца, новейшие первыми; перечитывается при открытии.
final portfolioHistoryListProvider =
    FutureProvider.autoDispose<List<PortfolioSnapshot>>((ref) async {
      final repository = ref.watch(portfolioHistoryRepositoryProvider);
      // Владелец неизвестен (сессия восстанавливается): не показываем «пусто».
      if (repository == null) throw const PortfolioHistoryFailure();
      return repository.list();
    }, retry: (_, _) => null);
