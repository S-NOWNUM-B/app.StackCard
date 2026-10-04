import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import 'data/memory_portfolio_draft_repository.dart';
import 'domain/portfolio_draft.dart';
import 'domain/portfolio_content.dart';
import 'domain/portfolio_draft_repository.dart';
import 'domain/portfolio_sync.dart';

final guestDraftTransferProvider = Provider<Future<void> Function(String uid)?>(
  (ref) => null,
);
final guestDraftAvailableProvider = FutureProvider<bool>(
  (ref) async => false,
  retry: (_, _) => null,
);

/// Native composition replaces this factory with UID-scoped disk repositories.
final portfolioDraftRepositoryFactoryProvider =
    Provider<PortfolioDraftRepository Function(String? uid)>((ref) {
      final repositories = <String?, PortfolioDraftRepository>{};
      return (uid) =>
          repositories.putIfAbsent(uid, MemoryPortfolioDraftRepository.new);
    });

final portfolioDraftRepositoryProvider = Provider<PortfolioDraftRepository>((
  ref,
) {
  final factory = ref.watch(portfolioDraftRepositoryFactoryProvider);
  if (ref.watch(accountAuthRepositoryProvider) == null) return factory(null);
  final session = ref.watch(
    accountSessionProvider.select(
      (session) => (
        ready: session.hasValue && !session.hasError && !session.isLoading,
        uid: !session.hasError && !session.isLoading
            ? session.value?.uid
            : null,
      ),
    ),
  );
  // Failure/restoring never falls back to the guest or previous account draft.
  if (!session.ready) {
    return const _LockedDraftRepository();
  }
  final uid = session.uid;
  if (uid != null) {
    final repository = factory(uid);
    if (repository is SyncPortfolioDraftRepository) {
      ref.onDispose(() => repository.dispose().ignore());
    }
    return repository;
  }
  if (ref.watch(guestAccessProvider)) return factory(null);
  return const _LockedDraftRepository();
});

final portfolioSyncRepositoryProvider = Provider<SyncPortfolioDraftRepository?>(
  (ref) {
    final repository = ref.watch(portfolioDraftRepositoryProvider);
    return repository is SyncPortfolioDraftRepository ? repository : null;
  },
);

final portfolioSyncStreamProvider = StreamProvider<PortfolioSyncState>(
  (ref) =>
      ref.watch(portfolioSyncRepositoryProvider)?.watchSyncState() ??
      Stream.value(
        const PortfolioSyncState(status: PortfolioSyncStatus.localOnly),
      ),
  retry: (_, _) => null,
);

final portfolioSyncStateProvider = Provider<PortfolioSyncState>((ref) {
  final repository = ref.watch(portfolioSyncRepositoryProvider);
  final stream = ref.watch(portfolioSyncStreamProvider);
  if (!stream.isLoading && stream.hasError) {
    return const PortfolioSyncState(
      status: PortfolioSyncStatus.error,
      failure: PortfolioSyncFailure(PortfolioSyncFailureKind.unavailable),
    );
  }
  return (!stream.isLoading ? stream.value : null) ??
      repository?.syncState ??
      const PortfolioSyncState(status: PortfolioSyncStatus.localOnly);
});

/// Unconfigured previews retain their local-only presentation.
final portfolioSyncVisibleProvider = Provider<bool>(
  (ref) =>
      ref.watch(accountAuthRepositoryProvider) != null ||
      ref.watch(portfolioSyncRepositoryProvider) != null,
);

class _LockedDraftRepository implements PortfolioDraftRepository {
  const _LockedDraftRepository();
  static const _failure = PortfolioDraftFailure(
    PortfolioDraftFailureKind.unavailable,
  );

  @override
  Future<PortfolioDraft?> read() async => throw _failure;
  @override
  Future<PortfolioDraft> saveNotes(String notes) async => throw _failure;
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async => throw _failure;
}
