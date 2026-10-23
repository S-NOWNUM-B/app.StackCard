import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_stackcard/features/portfolio_draft/data/firestore_developer_card_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/developer_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_stackcard/features/media/media.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'support/developer_card_fixture.dart';

void main() {
  test(
    'reads publishedAt as actual Firestore Timestamp without mutating snapshot',
    () async {
      final db = _Database();
      final timestamp = Timestamp.fromDate(DateTime.utc(2026, 10, 21));
      final raw = {...publicCardFixture(), 'publishedAt': timestamp};
      final repository = FirestoreDeveloperCardRepository(
        firestore: db,
        ownerUid: 'owner',
        isActive: () => true,
      );
      final future = repository.watch(publication()).first;
      db.changes.add(_Snapshot(raw));
      final card = await future;
      expect(card.name, 'Анна Ёлкина');
      expect(card.url, publication().url);
      expect(raw['publishedAt'], same(timestamp));
      await db.changes.close();
    },
  );

  test('subscribes only to public document and drops cached, withdrawn or changed versions', () async {
    final db = _Database();
    final repository = FirestoreDeveloperCardRepository(
      firestore: db,
      ownerUid: 'owner',
      isActive: () => true,
    );
    final stream = repository.watch(publication());
    final result = expectLater(
      stream,
      emitsInOrder([
        emitsError(isA<DeveloperCardFailure>()),
        isA<DeveloperCard>().having(
          (v) => v.name,
          'published name',
          'Анна Ёлкина',
        ),
        emitsError(
          isA<DeveloperCardFailure>().having(
            (e) => e.kind,
            'kind',
            DeveloperCardFailureKind.unpublished,
          ),
        ),
        emitsError(
          isA<DeveloperCardFailure>().having(
            (e) => e.kind,
            'kind',
            DeveloperCardFailureKind.stale,
          ),
        ),
        emitsDone,
      ]),
    );
    db.changes.add(_Snapshot(publicCardFixture(), cache: true));
    db.changes.add(_Snapshot(publicCardFixture()));
    db.changes.add(_Snapshot(null));
    db.changes.add(_Snapshot({...publicCardFixture(), 'version': 2}));
    await db.changes.close();
    await result;
    expect(db.paths, ['publicDocuments/$publicId']);
    expect(db.metadata, isTrue);
  });
  test('validates inline JPEG and never reads private owner media', () async {
    final db = _Database();
    final bytes = image.encodeJpg(image.Image(width: 16, height: 16));
    final raw = publicCardFixture();
    (raw['content'] as Map)['profile']['avatarUrl'] =
        'data:image/jpeg;base64,${base64Encode(bytes)}';
    final repository = FirestoreDeveloperCardRepository(
      firestore: db,
      ownerUid: 'owner',
      isActive: () => true,
    );
    final value = repository.watch(publication()).first;
    db.changes.add(_Snapshot(raw));
    final card = await value;
    expect(card.avatarBytes, bytes);
    await db.changes.close();
    expect(db.paths, ['publicDocuments/$publicId']);
  });
  test(
    'late avatar validation result is rejected after owner transition',
    () async {
      final db = _Database();
      var checks = 0;
      final raw = publicCardFixture();
      final bytes = image.encodeJpg(image.Image(width: 16, height: 16));
      (raw['content'] as Map)['profile']['avatarUrl'] =
          'data:image/jpeg;base64,${base64Encode(bytes)}';
      final repository = FirestoreDeveloperCardRepository(
        firestore: db,
        ownerUid: 'owner',
        isActive: () => ++checks == 1,
      );
      final result = expectLater(
        repository.watch(publication()).first,
        throwsA(isA<DeveloperCardFailure>()),
      );
      db.changes.add(_Snapshot(raw));
      await result;
      await db.changes.close();
    },
  );
  test(
    'a local pending public write never becomes confirmed card data',
    () async {
      final db = _Database();
      final repository = FirestoreDeveloperCardRepository(
        firestore: db,
        ownerUid: 'owner',
        isActive: () => true,
      );
      final result = expectLater(
        repository.watch(publication()).first,
        throwsA(isA<DeveloperCardFailure>()),
      );
      db.changes.add(_Snapshot(publicCardFixture(), pending: true));
      await result;
      await db.changes.close();
    },
  );
  test(
    'legacy external avatar uses bounded reader before card rendering',
    () async {
      final db = _Database();
      final reader = _AvatarReader();
      final raw = publicCardFixture();
      (raw['content'] as Map)['profile']['avatarUrl'] =
          'https://images.unsplash.com/fixture?w=512';
      final repository = FirestoreDeveloperCardRepository(
        firestore: db,
        ownerUid: 'owner',
        isActive: () => true,
        legacyAvatarReader: reader,
      );
      final future = repository.watch(publication()).first;
      db.changes.add(_Snapshot(raw));
      final card = await future;
      expect(card.avatarBytes, reader.bytes);
      expect(reader.urls, ['https://images.unsplash.com/fixture?w=512']);
      await db.changes.close();
    },
  );
}

class _Database implements FirebaseFirestore {
  final changes = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
  final paths = <String>[];
  bool metadata = false;
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) {
    paths.add(path);
    return _Reference(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// SDK adapter seam: как в существующих Firestore adapter tests.
// ignore: subtype_of_sealed_class
class _Reference implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.db);
  final _Database db;
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    db.metadata = includeMetadataChanges;
    return db.changes.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// ignore: subtype_of_sealed_class
class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value, {this.cache = false, this.pending = false});
  final Map<String, dynamic>? value;
  final bool cache, pending;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
  @override
  SnapshotMetadata get metadata => _Metadata(cache, pending);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Metadata implements SnapshotMetadata {
  _Metadata(this.isFromCache, this.hasPendingWrites);
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _AvatarReader implements PortfolioLegacyAvatarReader {
  final bytes = image.encodeJpg(image.Image(width: 16, height: 16));
  final urls = <String>[];
  @override
  Future<Uint8List> read(String url) async {
    urls.add(url);
    return bytes;
  }
}
