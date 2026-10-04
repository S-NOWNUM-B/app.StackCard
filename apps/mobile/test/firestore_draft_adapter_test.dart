import 'dart:async';

import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_sync.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Cloud codec keeps private notes separate and uses server timestamp',
    () {
      final draft = CloudPortfolioDraft(
        ownerUid: 'owner',
        mutationId: 'mutation-1',
        localRevision: 42,
        notes: 'Private notes',
        content: PortfolioContent(),
        updatedAt: DateTime.utc(2000),
      );
      final encoded = encodeCloudPortfolioDraft(draft);
      expect(encoded['updatedAt'], isA<FieldValue>());
      expect(encoded['notes'], 'Private notes');
      expect((encoded['content'] as Map).containsKey('notes'), isFalse);
      final decoded = decodeCloudPortfolioDraft({
        ...encoded,
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 4)),
      }, ownerUid: 'owner');
      expect(decoded.localRevision, 42);
      expect(decoded.mutationId, 'mutation-1');
      expect(decoded.content, draft.content);
      expect(decoded.updatedAt, DateTime.utc(2026, 10, 4));
    },
  );

  test('Unknown schema, foreign owner and malformed data fail closed', () {
    for (final patch in <Map<String, dynamic>>[
      {'schemaVersion': 99},
      {'schemaVersion': 2.0},
      {'schemaVersion': '2'},
      {'ownerUid': 'another'},
      {'localRevision': -1},
      {'localRevision': 0},
      {'localRevision': 1.5},
      {'mutationId': ''},
      {'notes': null},
      {'content': <String, dynamic>{}},
      {'extraField': true},
      {'updatedAt': '2026-10-04T00:00:00.000Z'},
    ]) {
      expect(
        () => decodeCloudPortfolioDraft({
          ..._data(),
          ...patch,
        }, ownerUid: 'owner'),
        throwsA(_failure(PortfolioSyncFailureKind.invalidData)),
        reason: patch.toString(),
      );
    }
  });

  test(
    'Legacy cloud schema remains readable and next write upgrades to version 2',
    () {
      final legacy = decodeCloudPortfolioDraft(_data(), ownerUid: 'owner');
      final upgraded = encodeCloudPortfolioDraft(legacy);
      expect(upgraded['schemaVersion'], 2);
      expect(upgraded['notes'], legacy.notes);
      expect(upgraded['mutationId'], legacy.mutationId);
      expect(upgraded['localRevision'], legacy.localRevision);
      final restored = decodeCloudPortfolioDraft({
        ...upgraded,
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 4)),
      }, ownerUid: 'owner');
      expect(restored.content, legacy.content);
    },
  );

  test('Unresolved server timestamp is accepted only for pending snapshot', () {
    final data = {..._data(), 'updatedAt': null};
    expect(
      () => decodeCloudPortfolioDraft(data, ownerUid: 'owner'),
      throwsA(_failure(PortfolioSyncFailureKind.invalidData)),
    );
    expect(
      decodeCloudPortfolioDraft(
        data,
        ownerUid: 'owner',
        allowUnresolvedTimestamp: true,
      ).updatedAt,
      isNull,
    );
  });

  test('SDK errors have typed categories without exposing SDK messages', () {
    final cases = <String, PortfolioSyncFailureKind>{
      'permission-denied': PortfolioSyncFailureKind.permissionDenied,
      'unauthenticated': PortfolioSyncFailureKind.unauthenticated,
      'unavailable': PortfolioSyncFailureKind.network,
      'deadline-exceeded': PortfolioSyncFailureKind.network,
      'invalid-argument': PortfolioSyncFailureKind.invalidData,
      'resource-exhausted': PortfolioSyncFailureKind.unavailable,
    };
    for (final entry in cases.entries) {
      expect(
        portfolioSyncFailureFromFirestore(
          FirebaseException(plugin: 'cloud_firestore', code: entry.key),
        ).kind,
        entry.value,
      );
    }
    expect(
      portfolioSyncFailureFromFirestore(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'invalid-argument',
          message: 'Document size exceeds the maximum',
        ),
      ).kind,
      PortfolioSyncFailureKind.oversized,
    );
  });

  test('Adapter rejects foreign mutation before SDK write', () async {
    final firestore = _Firestore();
    final repository = FirestorePortfolioDraftRepository(
      firestore: firestore,
      uid: 'owner',
    );
    await expectLater(
      repository.write(
        CloudPortfolioDraft(
          ownerUid: 'foreign',
          mutationId: 'foreign-mutation',
          localRevision: 1,
          notes: '',
        ),
      ),
      throwsA(_failure(PortfolioSyncFailureKind.permissionDenied)),
    );
    expect(firestore.document.path, 'accounts/owner/drafts/current');
    expect(firestore.document.writes, isEmpty);
    await firestore.document.events.close();
  });

  test(
    'Transfer preflight reads server and never treats network error as empty',
    () async {
      final firestore = _Firestore();
      final repository = FirestorePortfolioDraftRepository(
        firestore: firestore,
        uid: 'owner',
      );
      firestore.document.getResponses.add(_data());
      expect(await repository.hasDraftOnServer(), isTrue);
      firestore.document.getResponses.add(null);
      expect(await repository.hasDraftOnServer(), isFalse);
      firestore.document.getFailures.add(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await expectLater(
        repository.hasDraftOnServer(),
        throwsA(_failure(PortfolioSyncFailureKind.network)),
      );
      expect(firestore.document.getSources, [
        Source.server,
        Source.server,
        Source.server,
      ]);
      await firestore.document.events.close();
    },
  );

  test(
    'Adapter forwards SDK metadata and includes metadata-only events',
    () async {
      final firestore = _Firestore();
      final repository = FirestorePortfolioDraftRepository(
        firestore: firestore,
        uid: 'owner',
      );
      final results = <DraftRemoteEvent>[];
      final subscription = repository.watch().listen(results.add);
      firestore.document.events.add(
        _Snapshot(_data(), fromCache: true, pending: false),
      );
      firestore.document.events.add(
        _Snapshot(
          {..._data(), 'updatedAt': null},
          fromCache: true,
          pending: true,
        ),
      );
      firestore.document.events.add(
        _Snapshot(_data(), fromCache: false, pending: false),
      );
      await Future<void>.delayed(Duration.zero);
      expect(firestore.document.includeMetadataChanges, isTrue);
      expect(results.map((event) => event.fromCache), [true, true, false]);
      expect(results.map((event) => event.hasPendingWrites), [
        false,
        true,
        false,
      ]);
      expect(results[1].draft!.updatedAt, isNull);
      await subscription.cancel();
      await firestore.document.events.close();
    },
  );

  test(
    'Adapter stream maps permission error and cancels SDK listener',
    () async {
      final firestore = _Firestore();
      final repository = FirestorePortfolioDraftRepository(
        firestore: firestore,
        uid: 'owner',
      );
      final failure = expectLater(
        repository.watch(),
        emitsError(_failure(PortfolioSyncFailureKind.permissionDenied)),
      );
      firestore.document.events.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await failure;
      await firestore.document.events.close();
    },
  );
}

Matcher _failure(PortfolioSyncFailureKind kind) =>
    isA<PortfolioSyncFailure>().having((failure) => failure.kind, 'kind', kind);

Map<String, dynamic> _data() => {
  'schemaVersion': 1,
  'ownerUid': 'owner',
  'mutationId': 'mutation-1',
  'localRevision': 1,
  'notes': 'Private notes',
  'content': encodePortfolioContent(PortfolioContent()),
  'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 4)),
};

class _Firestore extends Fake implements FirebaseFirestore {
  late _Document document;
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) {
    return document = _Document(path);
  }
}

// Unit-test SDK double; native acceptance covers real SDK objects.
// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.path);
  @override
  final String path;
  final metadataRequests = <bool>[];
  bool get includeMetadataChanges => metadataRequests.last;
  final writes = <Map<String, dynamic>>[];
  final getResponses = <Map<String, dynamic>?>[];
  final getFailures = <Object>[];
  final getSources = <Source>[];
  final events =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    writes.add(data);
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    getSources.add(options!.source);
    if (getFailures.isNotEmpty) throw getFailures.removeAt(0);
    return _Snapshot(
      getResponses.removeAt(0),
      fromCache: false,
      pending: false,
    );
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    metadataRequests.add(includeMetadataChanges);
    return events.stream;
  }
}

// Unit-test SDK double; native acceptance covers real SDK objects.
// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this._data, {required bool fromCache, required bool pending})
    : metadata = _Metadata(fromCache, pending);
  final Map<String, dynamic>? _data;
  @override
  final SnapshotMetadata metadata;
  @override
  Map<String, dynamic>? data() => _data;
  @override
  bool get exists => _data != null;
}

class _Metadata extends Fake implements SnapshotMetadata {
  _Metadata(this.isFromCache, this.hasPendingWrites);
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
}
