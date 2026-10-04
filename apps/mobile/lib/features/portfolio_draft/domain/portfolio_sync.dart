import 'portfolio_content.dart';
import 'portfolio_draft.dart';
import 'portfolio_draft_repository.dart';

enum PortfolioSyncStatus { localOnly, loading, pending, synced, error }

enum PortfolioSyncFailureKind {
  network,
  permissionDenied,
  unauthenticated,
  invalidData,
  unavailable,
  oversized,
}

final class PortfolioSyncFailure implements Exception {
  const PortfolioSyncFailure(this.kind);
  final PortfolioSyncFailureKind kind;
}

final class PortfolioSyncState {
  const PortfolioSyncState({
    required this.status,
    this.failure,
    this.lastSyncedAt,
  });

  final PortfolioSyncStatus status;
  final PortfolioSyncFailure? failure;
  final DateTime? lastSyncedAt;
}

/// A whole-document mutation. Revision is local to one device, not a clock.
final class CloudPortfolioDraft {
  CloudPortfolioDraft({
    required this.ownerUid,
    required this.mutationId,
    required this.localRevision,
    required this.notes,
    this.content,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt?.toUtc();

  final String ownerUid;
  final String mutationId;
  final int localRevision;
  final String notes;
  final PortfolioContent? content;
  final DateTime? updatedAt;
}

final class DraftRemoteEvent {
  const DraftRemoteEvent({
    required this.draft,
    required this.fromCache,
    required this.hasPendingWrites,
  });

  final CloudPortfolioDraft? draft;
  final bool fromCache;
  final bool hasPendingWrites;
}

/// The adapter binds this stream and every write to a single account UID.
abstract interface class RemotePortfolioDraftRepository {
  Stream<DraftRemoteEvent> watch();
  Future<void> write(CloudPortfolioDraft draft);
}

abstract interface class SyncPortfolioDraftRepository
    implements PortfolioDraftRepository {
  PortfolioSyncState get syncState;
  Stream<PortfolioSyncState> watchSyncState();
  Stream<PortfolioDraft?> watchDraft();
  Future<void> retry();
  Future<void> dispose();
}
