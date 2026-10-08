import 'dart:async';
import 'dart:io';

import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart';
import 'package:app_stackcard/features/portfolio_draft/data/local_draft_accounts.dart';
import 'package:app_stackcard/features/portfolio_draft/data/synced_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late _Server server;
  final repositories = <SyncedPortfolioDraftRepository>[];
  final remotes = <_Remote>[];
  const uid = 'account-a';
  var mutation = 0;

  SyncedPortfolioDraftRepository repository({
    String owner = uid,
    Box<dynamic>? storage,
    _Remote? remote,
    bool Function()? isActive,
    Duration retryDelay = const Duration(hours: 1),
    HivePortfolioSyncMetadataStore? metadata,
  }) {
    final targetBox = storage ?? box;
    final targetRemote = remote ?? server.client(owner);
    remotes.add(targetRemote);
    final value = SyncedPortfolioDraftRepository(
      ownerUid: owner,
      local: LocalDraftAccounts(targetBox).repositoryForUser(owner),
      metadata:
          metadata ??
          HivePortfolioSyncMetadataStore(targetBox, ownerUid: owner),
      remote: targetRemote,
      isActive: isActive,
      retryDelay: retryDelay,
      mutationId: () => 'mutation-${++mutation}',
    );
    repositories.add(value);
    return value;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stackcard-sync-test-');
    box = await Hive.openBox<dynamic>('draft', path: directory.path);
    server = _Server();
    mutation = 0;
  });

  tearDown(() async {
    for (final repository in repositories) {
      await repository.dispose();
    }
    repositories.clear();
    for (final remote in remotes.toSet()) {
      await remote.close();
    }
    remotes.clear();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'Offline Save completes durably while the remote write is unresolved',
    () async {
      final remote = server.client(uid);
      final synced = repository(remote: remote);
      final content = PortfolioContent(resumeText: 'Exact offline snapshot');
      final saved = await synced
          .save(content, expectedRevision: 0, notes: 'Private notes')
          .timeout(const Duration(seconds: 1));
      await _until(() => remote.writes.length == 1);
      expect(saved.pendingSync, isTrue);
      expect((await synced.read())!.content!.resumeText, content.resumeText);
      final outbox = (await HivePortfolioSyncMetadataStore(
        box,
        ownerUid: uid,
      ).read())!;
      expect(outbox.pending, isTrue);
      expect(outbox.draft.notes, 'Private notes');
      expect(outbox.draft.content!.resumeText, content.resumeText);
      expect(remote.writes.single.completion.isCompleted, isFalse);
      expect(synced.syncState.status, PortfolioSyncStatus.pending);
      expect(synced.syncState.confirmedMutationId, isNull);
    },
  );

  test(
    'Reconnect ACK marks only the durable captured version synced',
    () async {
      final remote = server.client(uid);
      final synced = repository(remote: remote);
      await synced.saveNotes('Reconnect me');
      await _until(() => remote.writes.isNotEmpty);
      server.commit(remote.writes.single);
      await _until(() => synced.syncState.status == PortfolioSyncStatus.synced);
      expect((await synced.read())!.pendingSync, isFalse);
      expect(synced.syncState.lastSyncedAt, server.latest(uid)!.updatedAt);
      expect(
        synced.syncState.confirmedMutationId,
        remote.writes.single.draft.mutationId,
      );
      expect(
        (await HivePortfolioSyncMetadataStore(
          box,
          ownerUid: uid,
        ).read())!.pending,
        isFalse,
      );
    },
  );

  test(
    'Real Hive reopen delivers the same outbox and ignores disposed late ACK',
    () async {
      final remote = server.client(uid);
      final first = repository(remote: remote);
      await first.saveNotes('Survive restart');
      await _until(() => remote.writes.isNotEmpty);
      final originalMutation = remote.writes.single.draft.mutationId;
      await first.dispose().timeout(const Duration(seconds: 1));
      await box.close();
      box = await Hive.openBox<dynamic>('draft', path: directory.path);
      final restartedRemote = server.client(uid);
      final restarted = repository(remote: restartedRemote);
      expect((await restarted.read())!.notes, 'Survive restart');
      await _until(() => restartedRemote.writes.isNotEmpty);
      expect(restartedRemote.writes.single.draft.mutationId, originalMutation);
      remote.writes.single.completion.complete();
      await Future<void>.delayed(Duration.zero);
      expect((await restarted.read())!.pendingSync, isTrue);
      server.commit(restartedRemote.writes.single);
      await _until(
        () => restarted.syncState.status == PortfolioSyncStatus.synced,
      );
    },
  );

  test('Crash between cache Save and outbox write recovers the exact local version', () async {
    await LocalDraftAccounts(box)
        .repositoryForUser(uid)
        .saveNotes('Cache-first crash');
    await box.close();
    box = await Hive.openBox<dynamic>('draft', path: directory.path);
    final remote = server.client(uid);
    final synced = repository(remote: remote);
    expect((await synced.read())!.notes, 'Cache-first crash');
    await _until(() => remote.writes.isNotEmpty);
    expect(remote.writes.single.draft.notes, 'Cache-first crash');
    expect(remote.writes.single.draft.localRevision, 1);
  });

  test('Older ACK cannot clear a newer local Save', () async {
    final remote = server.client(uid);
    final synced = repository(remote: remote);
    await synced.saveNotes('First');
    await _until(() => remote.writes.length == 1);
    await synced.saveNotes('Second');
    server.commit(remote.writes.first);
    await _until(() => remote.writes.length == 2);
    final pending = (await synced.read())!;
    expect(pending.notes, 'Second');
    expect(pending.revision, 2);
    expect(pending.pendingSync, isTrue);
    expect(synced.syncState.confirmedMutationId, isNull);
    expect(
      (await HivePortfolioSyncMetadataStore(
        box,
        ownerUid: uid,
      ).read())!.pending,
      isTrue,
    );
    server.commit(remote.writes.last);
    await _until(() => synced.syncState.status == PortfolioSyncStatus.synced);
    expect((await synced.read())!.notes, 'Second');
    expect((await synced.read())!.pendingSync, isFalse);
    expect(
      synced.syncState.confirmedMutationId,
      remote.writes.last.draft.mutationId,
    );
  });

  test(
    'SDK cache and local pending snapshots cannot manufacture a server ACK',
    () async {
      final remote = server.client(uid);
      final synced = repository(remote: remote);
      await synced.saveNotes('Still offline');
      await _until(() => remote.writes.isNotEmpty);
      final draft = remote.writes.single.draft;
      remote.emit(
        DraftRemoteEvent(
          draft: draft,
          fromCache: true,
          hasPendingWrites: false,
        ),
      );
      remote.emit(
        DraftRemoteEvent(
          draft: draft,
          fromCache: false,
          hasPendingWrites: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect((await synced.read())!.pendingSync, isTrue);
      expect(synced.syncState.status, PortfolioSyncStatus.pending);
    },
  );

  test(
    'Network failure retains notes and outbox, explicit retry delivers them',
    () async {
      final remote = server.client(
        uid,
      )..failure = const PortfolioSyncFailure(PortfolioSyncFailureKind.network);
      final synced = repository(remote: remote);
      await synced.saveNotes('Keep after failure');
      await _until(() => synced.syncState.status == PortfolioSyncStatus.error);
      expect((await synced.read())!.notes, 'Keep after failure');
      expect(
        (await HivePortfolioSyncMetadataStore(
          box,
          ownerUid: uid,
        ).read())!.pending,
        isTrue,
      );
      remote.failure = null;
      await synced.retry();
      await _until(() => remote.writes.length >= 2);
      server.commit(remote.writes.last);
      await _until(() => synced.syncState.status == PortfolioSyncStatus.synced);
      expect(server.latest(uid)!.notes, 'Keep after failure');
    },
  );

  test(
    'Bounded automatic retry resumes after a transient network failure',
    () async {
      final remote = server.client(
        uid,
      )..failure = const PortfolioSyncFailure(PortfolioSyncFailureKind.network);
      final synced = repository(
        remote: remote,
        retryDelay: const Duration(milliseconds: 20),
      );
      await synced.saveNotes('Automatic reconnect');
      await _until(() => synced.syncState.status == PortfolioSyncStatus.error);
      remote.failure = null;
      await _until(() => remote.writes.length == 2);
      server.commit(remote.writes.last);
      await _until(() => synced.syncState.status == PortfolioSyncStatus.synced);
    },
  );

  test('Permission errors wait for explicit retry without an automatic request loop', () async {
    final remote = server.client(uid)
      ..failure = const PortfolioSyncFailure(
        PortfolioSyncFailureKind.permissionDenied,
      );
    final synced = repository(
      remote: remote,
      retryDelay: const Duration(milliseconds: 5),
    );
    await synced.saveNotes('Access failure');
    await _until(() => synced.syncState.status == PortfolioSyncStatus.error);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(remote.writes.length, 1);
    remote.failure = null;
    await synced.retry();
    await _until(() => remote.writes.length == 2);
    server.commit(remote.writes.last);
    await _until(() => synced.syncState.status == PortfolioSyncStatus.synced);
  });

  test(
    'Server commit order wins across clients with unrelated local revisions',
    () async {
      final secondBox = await Hive.openBox<dynamic>(
        'second-device',
        path: directory.path,
      );
      final remoteA = server.client(uid);
      final remoteB = server.client(uid);
      final a = repository(remote: remoteA);
      final b = repository(storage: secondBox, remote: remoteB);
      await a.read();
      await b.read();
      await a.saveNotes('A first');
      await _until(() => remoteA.writes.length == 1);
      server.commit(remoteA.writes.single);
      await _until(() => a.syncState.status == PortfolioSyncStatus.synced);
      await _untilAsync(() async => (await b.read())?.notes == 'A first');
      await b.saveNotes('B last');
      await _until(() => remoteB.writes.length == 1);
      server.commit(remoteB.writes.single);
      await _untilAsync(() async => (await a.read())?.notes == 'B last');
      expect(server.latest(uid)!.notes, 'B last');
      expect((await a.read())!.pendingSync, isFalse);
      expect((await b.read())!.pendingSync, isFalse);
      // Incoming localRevision=2 increments A's existing cache revision to 2;
      // it is never treated as a cross-client CAS or dropped as a conflict.
      expect((await a.read())!.revision, 2);
    },
  );

  test(
    'A pre-commit foreign event cannot roll back the just-acknowledged Save',
    () async {
      final remote = server.client(uid);
      final synced = repository(remote: remote);
      await synced.saveNotes('My new commit');
      await _until(() => remote.writes.isNotEmpty);
      server.install(_cloud(uid, 'old-other-mutation', 'Old server version'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      server.commit(remote.writes.single, emit: false);
      await _until(() => synced.syncState.status == PortfolioSyncStatus.synced);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect((await synced.read())!.notes, 'My new commit');
    },
  );

  test('ACK refresh retrieves a later server winner observed while send was pending', () async {
    final remote = server.client(uid);
    final synced = repository(remote: remote);
    await synced.saveNotes('My commit');
    await _until(() => remote.writes.isNotEmpty);
    server.commit(remote.writes.single, emit: false, complete: false);
    server.install(_cloud(uid, 'later-other-mutation', 'Later server winner'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    remote.writes.single.completion.complete();
    await _untilAsync(
      () async => (await synced.read())?.notes == 'Later server winner',
    );
    expect((await synced.read())!.pendingSync, isFalse);
  });

  test(
    'Read detects an external transfer/save and queues the new Hive revision',
    () async {
      final remote = server.client(uid);
      final synced = repository(remote: remote);
      await synced.read();
      await _until(() => synced.syncState.status == PortfolioSyncStatus.synced);
      await LocalDraftAccounts(box).guestRepository
          .saveNotes('Explicit guest transfer');
      await LocalDraftAccounts(box).transferGuestToUser(uid);
      expect((await synced.read())!.notes, 'Explicit guest transfer');
      await _until(() => remote.writes.isNotEmpty);
      expect(remote.writes.single.draft.notes, 'Explicit guest transfer');
    },
  );

  test(
    'UID change prevents new sends and a late ACK from touching either cache',
    () async {
      var active = true;
      final remoteA = server.client(uid);
      final a = repository(remote: remoteA, isActive: () => active);
      await a.saveNotes('Only A');
      await _until(() => remoteA.writes.isNotEmpty);
      active = false;
      final remoteB = server.client('account-b');
      final b = repository(owner: 'account-b', remote: remoteB);
      expect(await b.read(), isNull);
      remoteA.writes.single.completion.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        (await LocalDraftAccounts(
          box,
        ).repositoryForUser(uid).read())!.pendingSync,
        isTrue,
      );
      expect(await b.read(), isNull);
      await a.retry();
      expect(remoteA.writes.length, 1);
      await expectLater(
        a.saveNotes('Stale account write'),
        throwsA(isA<PortfolioDraftFailure>()),
      );
    },
  );

  test('Corrupt metadata is retained and cannot overwrite the existing local draft', () async {
    final local = LocalDraftAccounts(box).repositoryForUser(uid);
    await local.saveNotes('Keep original');
    final key = HivePortfolioSyncMetadataStore.storageKeyForUser(uid);
    await box.put(key, '{broken');
    final synced = repository();
    await expectLater(
      synced.read(),
      throwsA(_draftFailure(PortfolioDraftFailureKind.corrupted)),
    );
    await expectLater(
      synced.saveNotes('Overwrite'),
      throwsA(_draftFailure(PortfolioDraftFailureKind.corrupted)),
    );
    await synced.retry();
    expect(
      synced.syncState.failure?.kind,
      PortfolioSyncFailureKind.invalidData,
    );
    expect(box.get(key), '{broken');
    expect((await local.read())!.notes, 'Keep original');
  });

  test('A crash during remote hydration never replays downloaded content as a user edit', () async {
    final failing = _FailingMetadataBox(box);
    final remote = server.client(uid);
    final synced = repository(
      remote: remote,
      metadata: HivePortfolioSyncMetadataStore(failing, ownerUid: uid),
    );
    await synced.read();
    server.install(_cloud(uid, 'server-initial', 'Initial cloud draft'));
    await _untilAsync(
      () async => (await synced.read())?.notes == 'Initial cloud draft',
    );
    failing.failWrites = true;
    server.install(_cloud(uid, 'server-downloaded', 'Downloaded before crash'));
    await _until(() => synced.syncState.status == PortfolioSyncStatus.error);
    expect(
      (await LocalDraftAccounts(
        box,
      ).repositoryForUser(uid).read())!.pendingSync,
      isFalse,
    );
    await synced.dispose();
    await box.close();
    box = await Hive.openBox<dynamic>('draft', path: directory.path);
    server.install(
      _cloud(uid, 'server-later', 'Newer client version'),
      emit: false,
    );
    final restartedRemote = server.client(uid);
    final restarted = repository(remote: restartedRemote);
    await restarted.read();
    await _untilAsync(
      () async => (await restarted.read())?.notes == 'Newer client version',
    );
    expect(restartedRemote.writes, isEmpty);
    expect(server.latest(uid)!.notes, 'Newer client version');
  });

  test('An ACK metadata failure cannot requeue the already acknowledged cache after restart', () async {
    final failing = _FailingMetadataBox(box);
    final remote = server.client(uid);
    final synced = repository(
      remote: remote,
      metadata: HivePortfolioSyncMetadataStore(failing, ownerUid: uid),
    );
    await synced.saveNotes('Acknowledged user edit');
    await _until(() => remote.writes.isNotEmpty);
    failing.failWrites = true;
    server.commit(remote.writes.single, emit: false);
    await _until(() => synced.syncState.status == PortfolioSyncStatus.error);
    expect(
      (await LocalDraftAccounts(
        box,
      ).repositoryForUser(uid).read())!.pendingSync,
      isFalse,
    );
    expect(
      (await HivePortfolioSyncMetadataStore(
        box,
        ownerUid: uid,
      ).read())!.pending,
      isTrue,
    );
    await synced.dispose();
    await box.close();
    box = await Hive.openBox<dynamic>('draft', path: directory.path);
    server.install(
      _cloud(uid, 'server-later', 'A later client wins'),
      emit: false,
    );
    final restartedRemote = server.client(uid);
    final restarted = repository(remote: restartedRemote);
    await restarted.read();
    await _untilAsync(
      () async => (await restarted.read())?.notes == 'A later client wins',
    );
    expect(restartedRemote.writes, isEmpty);
    expect(server.latest(uid)!.notes, 'A later client wins');
  });

  test('A metadata-first server ACK acknowledges the exact transferred pending envelope', () async {
    final local = LocalDraftAccounts(box).repositoryForUser(uid);
    final saved = await local.saveNotes('Transferred exact bytes');
    await HivePortfolioSyncMetadataStore(box, ownerUid: uid).write(
      PortfolioSyncRecord(
        mutationId: 'transfer-server-ack',
        pending: false,
        draft: PortfolioDraft(
          notes: saved.notes,
          revision: saved.revision,
          updatedAt: saved.updatedAt,
          pendingSync: false,
          content: saved.content,
        ),
      ),
    );
    server.install(
      _cloud(uid, 'transfer-server-ack', saved.notes),
      emit: false,
    );
    final remote = server.client(uid);
    final synced = repository(remote: remote);
    expect((await synced.read())!.pendingSync, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(remote.writes, isEmpty);
    expect((await synced.read())!.revision, saved.revision);
  });

  test(
    'A metadata-first old ACK cannot acknowledge a higher local Save revision',
    () async {
      final local = LocalDraftAccounts(box).repositoryForUser(uid);
      final original = await local.saveNotes('Same notes');
      await HivePortfolioSyncMetadataStore(box, ownerUid: uid).write(
        PortfolioSyncRecord(
          mutationId: 'old-server-ack',
          pending: false,
          draft: PortfolioDraft(
            notes: original.notes,
            revision: original.revision,
            updatedAt: original.updatedAt,
            pendingSync: false,
            content: original.content,
          ),
        ),
      );
      final newer = await local.saveNotes('Same notes');
      final remote = server.client(uid);
      final synced = repository(remote: remote);
      expect((await synced.read())!.pendingSync, isTrue);
      await _until(() => remote.writes.isNotEmpty);
      expect(remote.writes.single.draft.localRevision, newer.revision);
      expect(remote.writes.single.draft.mutationId, isNot('old-server-ack'));
    },
  );

  test('saveNotes retains Builder content and a failing outbox write keeps durable Save', () async {
    final failing = _FailingMetadataBox(box);
    final remote = server.client(uid);
    final synced = repository(
      remote: remote,
      metadata: HivePortfolioSyncMetadataStore(failing, ownerUid: uid),
    );
    await synced.save(
      PortfolioContent(resumeText: 'Keep Builder'),
      expectedRevision: 0,
      notes: 'Original',
    );
    await _until(() => remote.writes.length == 1);
    server.commit(remote.writes.single);
    await _until(() => synced.syncState.status == PortfolioSyncStatus.synced);
    failing.failWrites = true;
    final saved = await synced.saveNotes('Durable despite outbox failure');
    expect(saved.content!.resumeText, 'Keep Builder');
    expect(
      (await LocalDraftAccounts(box).repositoryForUser(uid).read())!.notes,
      saved.notes,
    );
    await _until(() => synced.syncState.status == PortfolioSyncStatus.error);
    failing.failWrites = false;
    await synced.retry();
    await _until(() => remote.writes.length == 2);
    expect(remote.writes.last.draft.notes, saved.notes);
    server.commit(remote.writes.last);
    await _until(() => synced.syncState.status == PortfolioSyncStatus.synced);
  });
}

Matcher _draftFailure(PortfolioDraftFailureKind kind) =>
    isA<PortfolioDraftFailure>().having(
      (failure) => failure.kind,
      'kind',
      kind,
    );

Future<void> _until(bool Function() condition) =>
    _untilAsync(() async => condition());

Future<void> _untilAsync(Future<bool> Function() condition) async {
  for (var attempt = 0; attempt < 500; attempt++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  throw StateError('Timed out waiting for sync state');
}

CloudPortfolioDraft _cloud(String uid, String mutation, String notes) =>
    CloudPortfolioDraft(
      ownerUid: uid,
      mutationId: mutation,
      localRevision: 9000,
      notes: notes,
      updatedAt: DateTime.utc(2026, 10, 4),
    );

final class _Server {
  final _current = <String, CloudPortfolioDraft>{};
  final _clients = <_Remote>[];
  var _tick = 0;

  CloudPortfolioDraft? latest(String uid) => _current[uid];

  _Remote client(String uid) {
    final remote = _Remote(this, uid);
    _clients.add(remote);
    return remote;
  }

  void install(CloudPortfolioDraft draft, {bool emit = true}) {
    _current[draft.ownerUid] = draft;
    if (emit) {
      for (final client in _clients.where(
        (client) => client.uid == draft.ownerUid,
      )) {
        client.emit(
          DraftRemoteEvent(
            draft: draft,
            fromCache: false,
            hasPendingWrites: false,
          ),
        );
      }
    }
  }

  void commit(_Write write, {bool emit = true, bool complete = true}) {
    final draft = write.draft;
    install(
      CloudPortfolioDraft(
        ownerUid: draft.ownerUid,
        mutationId: draft.mutationId,
        localRevision: draft.localRevision,
        notes: draft.notes,
        content: draft.content,
        updatedAt: DateTime.utc(2026, 10, 4).add(Duration(seconds: ++_tick)),
      ),
      emit: emit,
    );
    if (complete && !write.completion.isCompleted) write.completion.complete();
  }
}

final class _Remote implements RemotePortfolioDraftRepository {
  _Remote(this.server, this.uid);
  final _Server server;
  final String uid;
  final _events = StreamController<DraftRemoteEvent>.broadcast();
  final writes = <_Write>[];
  PortfolioSyncFailure? failure;

  @override
  Stream<DraftRemoteEvent> watch() => Stream.multi((listener) {
    final subscription = _events.stream.listen(
      listener.add,
      onDone: listener.close,
    );
    listener.add(
      DraftRemoteEvent(
        draft: server.latest(uid),
        fromCache: false,
        hasPendingWrites: false,
      ),
    );
    listener.onCancel = subscription.cancel;
  });

  @override
  Future<void> write(CloudPortfolioDraft draft) {
    final write = _Write(draft);
    writes.add(write);
    final error = failure;
    if (error != null) return Future.error(error);
    return write.completion.future;
  }

  void emit(DraftRemoteEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> close() => _events.close();
}

final class _Write {
  _Write(this.draft);
  final CloudPortfolioDraft draft;
  final completion = Completer<void>();
}

final class _FailingMetadataBox implements Box<dynamic> {
  _FailingMetadataBox(this.delegate);
  final Box<dynamic> delegate;
  bool failWrites = false;

  @override
  bool containsKey(dynamic key) => delegate.containsKey(key);
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (failWrites) throw const FileSystemException('Injected outbox failure');
    await delegate.put(key, value);
  }

  @override
  Future<void> flush() => delegate.flush();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
