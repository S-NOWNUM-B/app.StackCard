import 'dart:async';
import 'dart:math';

import '../domain/portfolio_content.dart';
import '../domain/portfolio_draft.dart';
import '../domain/portfolio_draft_repository.dart';
import '../domain/portfolio_sync.dart';
import 'hive_portfolio_draft_repository.dart';
import 'hive_portfolio_sync_metadata_store.dart';

/// Hive owns durable Save; a UID-bound outbox delivers captured snapshots.
final class SyncedPortfolioDraftRepository
    implements SyncPortfolioDraftRepository {
  SyncedPortfolioDraftRepository({
    required this.ownerUid,
    required this._local,
    required this._metadata,
    required this._remote,
    bool Function()? isActive,
    this.retryDelay = const Duration(seconds: 15),
    String Function()? mutationId,
  }) : _isActive = isActive ?? (() => true),
       _mutationId = mutationId ?? _newMutationId;

  final String ownerUid;
  final HivePortfolioDraftRepository _local;
  final HivePortfolioSyncMetadataStore _metadata;
  final RemotePortfolioDraftRepository _remote;
  final bool Function() _isActive;
  final String Function() _mutationId;
  final Duration retryDelay;
  final _states = StreamController<PortfolioSyncState>.broadcast();
  final _drafts = StreamController<PortfolioDraft?>.broadcast();

  Future<void> _operations = Future.value();
  StreamSubscription<DraftRemoteEvent>? _subscription;
  Timer? _retryTimer;
  PortfolioSyncRecord? _record;
  _SendingMutation? _sending;
  bool _initialized = false;
  bool _needsServerRefresh = false;
  bool _disposed = false;
  PortfolioSyncState _state = const PortfolioSyncState(
    status: PortfolioSyncStatus.loading,
  );

  bool get _active => !_disposed && _isActive();

  @override
  PortfolioSyncState get syncState => _state;

  @override
  Stream<PortfolioSyncState> watchSyncState() => Stream.multi((listener) {
    final subscription = _states.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.add(_state);
    listener.onCancel = subscription.cancel;
  });

  @override
  Stream<PortfolioDraft?> watchDraft() => _drafts.stream;

  @override
  Future<PortfolioDraft?> read() async {
    final result = await _serial(() async {
      _requireActive();
      await _initialize();
      final local = await _local.read();
      final stored = await _metadata.read();
      _requireActive();
      await _reconcile(local, stored);
      return _local.read();
    });
    _kick();
    return result;
  }

  @override
  Future<PortfolioDraft> saveNotes(String notes) =>
      _save(() => _local.saveNotes(notes));

  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) => _save(
    () =>
        _local.save(content, expectedRevision: expectedRevision, notes: notes),
  );

  Future<PortfolioDraft> _save(Future<PortfolioDraft> Function() save) async {
    final result = await _serial(() async {
      _requireActive();
      await _initialize();
      // Corrupt metadata is retained, just like a corrupt original envelope.
      await _metadata.read();
      _requireActive();
      final draft = await save();
      if (!_active) return draft;
      final record = PortfolioSyncRecord(
        mutationId: _mutationId(),
        pending: true,
        draft: draft,
      );
      _record = record;
      _setState(PortfolioSyncStatus.pending);
      _emitDraft(draft);
      try {
        await _metadata.write(record);
      } catch (error) {
        // Save already succeeded. Its pending envelope repairs the outbox on
        // retry/restart, even if this second durable write failed.
        _setFailure(_syncFailure(error));
      }
      return draft;
    });
    _kick();
    return result;
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    final local = await _local.read();
    final stored = await _metadata.read();
    _requireActive();
    await _reconcile(local, stored);
    _initialized = true;
    if (_record?.pending == true) {
      _setState(PortfolioSyncStatus.pending);
    } else if (local != null && !_needsServerRefresh) {
      _setState(PortfolioSyncStatus.synced);
    }
    _listen();
  }

  Future<void> _reconcile(
    PortfolioDraft? local,
    PortfolioSyncRecord? stored,
  ) async {
    if (stored != null && local == null) {
      throw const PortfolioDraftFailure(PortfolioDraftFailureKind.corrupted);
    }
    _record = stored;
    if (local != null &&
        local.pendingSync &&
        stored?.pending == false &&
        _samePayload(local, stored!.draft)) {
      // A transfer journal may persist a proven server ACK before copying its
      // byte-for-byte guest envelope. Only that exact revision is acknowledged.
      final acknowledged = await _local.acknowledgeRevision(local.revision);
      if (!_active) return;
      if (acknowledged != null) {
        _needsServerRefresh = false;
        _setState(PortfolioSyncStatus.synced);
        _emitDraft(acknowledged);
        return;
      }
    }
    _needsServerRefresh = stored?.mutationId.startsWith('recovered-') == true;
    if (local != null &&
        (stored == null || !_sameSnapshot(local, stored.draft))) {
      // A process may stop between cache Save and metadata write. The original
      // pending envelope remains sufficient to recover the exact snapshot.
      _record = PortfolioSyncRecord(
        mutationId: local.pendingSync
            ? _mutationId()
            : (stored?.draft.revision == local.revision
                  ? stored!.mutationId
                  : 'recovered-${_mutationId()}'),
        pending: local.pendingSync,
        draft: local,
      );
      await _metadata.write(_record!);
      // A downloaded/acknowledged cache snapshot is never a new user edit.
      // A crash after hydrate/ACK but before metadata must not enqueue it.
      _needsServerRefresh = !local.pendingSync;
      _setState(
        local.pendingSync
            ? PortfolioSyncStatus.pending
            : PortfolioSyncStatus.loading,
      );
    }
  }

  void _listen() {
    if (!_active || _subscription != null) return;
    _subscription = _remote.watch().listen(
      (event) => _background(_serial(() => _receive(event))),
      onError: (Object error, StackTrace stack) {
        if (_active) _setFailure(_syncFailure(error));
      },
      onDone: () {
        _subscription = null;
      },
    );
  }

  Future<void> _receive(DraftRemoteEvent event) async {
    if (!_active || event.fromCache || event.hasPendingWrites) return;
    final remote = event.draft;
    if (remote != null && remote.ownerUid != ownerUid) {
      _setFailure(
        const PortfolioSyncFailure(PortfolioSyncFailureKind.invalidData),
      );
      return;
    }
    final local = await _local.read();
    if (!_active) return;
    await _reconcile(local, await _metadata.read());
    final record = _record;
    if (record?.pending == true) {
      if (remote?.mutationId == record!.mutationId) {
        await _acknowledge(record, syncedAt: remote?.updatedAt);
      } else if (_state.failure?.kind == PortfolioSyncFailureKind.network ||
          _state.failure?.kind == PortfolioSyncFailureKind.unavailable) {
        _setState(PortfolioSyncStatus.pending);
        _kick();
      }
      return;
    }
    if (remote == null) {
      if (record == null) _setState(PortfolioSyncStatus.synced);
      // Deleting a private remote draft is not part of Phase 8. Never clear a
      // durable local draft because a cache/server snapshot is absent.
      return;
    }
    await _hydrate(remote);
  }

  Future<void> _hydrate(CloudPortfolioDraft remote) async {
    if (!_active) return;
    if (remote.mutationId == _record?.mutationId) {
      _needsServerRefresh = false;
      _setState(PortfolioSyncStatus.synced, syncedAt: remote.updatedAt);
      return;
    }
    final current = await _local.read();
    if (!_active) return;
    final hydrated = await _local.hydrateRemote(
      remote,
      expectedRevision: current?.revision ?? 0,
    );
    if (!_active) return;
    final record = PortfolioSyncRecord(
      mutationId: remote.mutationId,
      pending: false,
      draft: hydrated,
    );
    await _metadata.write(record);
    _record = record;
    _needsServerRefresh = false;
    _setState(PortfolioSyncStatus.synced, syncedAt: remote.updatedAt);
    _emitDraft(hydrated);
  }

  void _kick() {
    if (!_active) return;
    _background(
      _serial(() async {
        if (!_active || _sending != null || _record?.pending != true) return;
        if (_state.status == PortfolioSyncStatus.error) return;
        // Confirm the outbox is durable before sending. This also repairs an
        // earlier metadata write failure without losing the completed Save.
        final captured = _record!;
        await _metadata.write(captured);
        if (!_active) return;
        final sending = _SendingMutation(captured);
        _sending = sending;
        _setState(PortfolioSyncStatus.pending);
        _background(_send(sending));
      }),
    );
  }

  Future<void> _send(_SendingMutation sending) async {
    try {
      final draft = sending.record.draft;
      await _remote.write(
        CloudPortfolioDraft(
          ownerUid: ownerUid,
          mutationId: sending.record.mutationId,
          localRevision: draft.revision,
          notes: draft.notes,
          content: draft.content,
        ),
      );
      if (!_active) return;
      await _serial(() async {
        if (!_active) return;
        await _acknowledge(sending.record);
        _sending = null;
        // A foreign snapshot seen while this mutation was pending does not
        // prove it committed after ours. Ask the stream for the current server
        // winner instead of replaying a potentially pre-commit snapshot.
        await _subscription?.cancel();
        _subscription = null;
        _listen();
      });
      _kick();
    } catch (error) {
      if (!_active) return;
      await _serial(() async {
        if (!_active) return;
        _sending = null;
        _setFailure(_syncFailure(error));
      });
    }
  }

  Future<void> _acknowledge(
    PortfolioSyncRecord captured, {
    DateTime? syncedAt,
  }) async {
    if (!_active ||
        _record?.mutationId != captured.mutationId ||
        _record?.pending != true) {
      return;
    }
    final acknowledged = await _local.acknowledgeRevision(
      captured.draft.revision,
    );
    if (!_active) return;
    if (acknowledged == null) return;
    final record = PortfolioSyncRecord(
      mutationId: captured.mutationId,
      pending: false,
      draft: acknowledged,
    );
    await _metadata.write(record);
    _record = record;
    _needsServerRefresh = false;
    _setState(PortfolioSyncStatus.synced, syncedAt: syncedAt);
    _emitDraft(acknowledged);
  }

  @override
  Future<void> retry() async {
    if (!_active) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      await _serial(() async {
        _requireActive();
        await _initialize();
        final local = await _local.read();
        final stored = await _metadata.read();
        await _reconcile(local, stored);
        await _subscription?.cancel();
        _subscription = null;
        if (!_active) return;
        _setState(
          _record?.pending == true
              ? PortfolioSyncStatus.pending
              : PortfolioSyncStatus.loading,
        );
        _listen();
      });
      _kick();
    } catch (error) {
      if (_active) _setFailure(_syncFailure(error));
    }
  }

  void _setFailure(PortfolioSyncFailure failure) {
    if (!_active) return;
    _state = PortfolioSyncState(
      status: PortfolioSyncStatus.error,
      failure: failure,
      lastSyncedAt: _state.lastSyncedAt,
    );
    _states.add(_state);
    if (failure.kind == PortfolioSyncFailureKind.network ||
        failure.kind == PortfolioSyncFailureKind.unavailable) {
      _retryTimer ??= Timer(retryDelay, () {
        _retryTimer = null;
        if (_active) _background(retry());
      });
    }
  }

  void _setState(PortfolioSyncStatus status, {DateTime? syncedAt}) {
    if (!_active) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _state = PortfolioSyncState(
      status: status,
      lastSyncedAt: syncedAt ?? _state.lastSyncedAt,
    );
    _states.add(_state);
  }

  void _emitDraft(PortfolioDraft draft) {
    if (_active) _drafts.add(draft);
  }

  void _requireActive() {
    if (!_active) {
      throw const PortfolioDraftFailure(PortfolioDraftFailureKind.unavailable);
    }
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _operations = _operations.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  void _background(Future<void> operation) {
    unawaited(() async {
      try {
        await operation;
      } catch (error) {
        if (_active) _setFailure(_syncFailure(error));
      }
    }());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _retryTimer?.cancel();
    await _subscription?.cancel();
    // Offline SDK writes may never complete before reconnect. Disposal never
    // awaits them, and their late callbacks cannot access a closed Hive box.
    await _states.close();
    await _drafts.close();
  }

  static bool _samePayload(PortfolioDraft a, PortfolioDraft b) =>
      a.revision == b.revision &&
      a.notes == b.notes &&
      a.content == b.content &&
      a.updatedAt == b.updatedAt;

  static bool _sameSnapshot(PortfolioDraft a, PortfolioDraft b) =>
      _samePayload(a, b) && a.pendingSync == b.pendingSync;

  static PortfolioSyncFailure _syncFailure(Object error) {
    if (error is PortfolioSyncFailure) return error;
    if (error is PortfolioDraftFailure &&
        (error.kind == PortfolioDraftFailureKind.corrupted ||
            error.kind == PortfolioDraftFailureKind.unsupportedVersion ||
            error.kind == PortfolioDraftFailureKind.invalidContent)) {
      return const PortfolioSyncFailure(PortfolioSyncFailureKind.invalidData);
    }
    return const PortfolioSyncFailure(PortfolioSyncFailureKind.unavailable);
  }

  static String _newMutationId() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

final class _SendingMutation {
  const _SendingMutation(this.record);
  final PortfolioSyncRecord record;
}
