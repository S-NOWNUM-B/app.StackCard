import 'dart:async';

import 'package:app_stackcard/features/inbox/data/firestore_inbox_repository.dart';
import 'package:app_stackcard/features/inbox/inbox.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/inbox_fakes.dart';

Map<String, dynamic> _raw({String id = requestId}) => {
  'schemaVersion': 1,
  'requestId': id,
  'publicId': 'abcdef0123456789abcdef0123456789',
  'documentId': 'resume',
  'documentTitle': 'Published resume',
  'name': 'Visitor',
  'email': 'visitor@example.com',
  'message': 'Hello\nPlease contact me.',
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 9)),
  'readAt': null,
};
final _invalid = isA<InboxFailure>().having(
  (error) => error.kind,
  'kind',
  InboxFailureKind.invalidData,
);
String _id(int value) => value.toRadixString(16).padLeft(32, '0');

void main() {
  test('trusted ten-field payload preserves multiline message, published title and source document ID literally', () {
    final data = _raw()
      ..['documentTitle'] = ' Published\r\nresume '
      ..['documentId'] = ' source ${'x' * 190} ';
    final result = decodeContactRequest(data, requestId);
    expect(result.documentTitle, data['documentTitle']);
    expect(result.documentId, data['documentId']);
    expect(result.message, 'Hello\nPlease contact me.');
    expect(result.createdAt.isUtc, isTrue);
    expect(result.unread, isTrue);
    data['readAt'] = Timestamp.fromDate(DateTime.utc(2026, 10, 10));
    expect(
      decodeContactRequest(data, requestId).readAt,
      DateTime.utc(2026, 10, 10),
    );
  });
  test('parser rejects unsupported schema, extra private fields, wrong IDs and non-server timestamps', () {
    for (final data in [
      {..._raw(), 'schemaVersion': 1.0},
      {..._raw(), 'schemaVersion': 2},
      {..._raw(), 'ownerUid': 'a'},
      {..._raw()}..remove('readAt'),
      {..._raw(), 'requestId': _id(2)},
      {..._raw(), 'publicId': 'legacy-public-id'},
      {..._raw(), 'createdAt': '2026-10-09'},
      {..._raw(), 'readAt': 123},
      {..._raw(), 'readAt': Timestamp.fromDate(DateTime.utc(2026, 10, 8))},
      {..._raw(), 'documentId': 'a/b'},
      {..._raw(), 'documentId': 'x' * 201},
      {..._raw(), 'documentId': 'a\nb'},
    ]) {
      expect(
        () => decodeContactRequest(data, requestId),
        throwsA(_invalid),
        reason: '$data',
      );
    }
  });
  test('normalized visitor fields must agree with trusted submit contract', () {
    for (final data in [
      {..._raw(), 'name': ' Visitor'},
      {..._raw(), 'name': 'A\nB'},
      {..._raw(), 'email': 'Visitor@example.com'},
      {..._raw(), 'email': 'a@-example.com'},
      {..._raw(), 'email': 'a@localhost'},
      {..._raw(), 'email': 'a@example..com'},
      {..._raw(), 'message': 'Hello\r\nPlease contact me.'},
      {..._raw(), 'message': ' Hello '},
      {..._raw(), 'message': 'hello\u0000'},
      {..._raw(), 'message': 'x' * 4001},
    ]) {
      expect(() => decodeContactRequest(data, requestId), throwsA(_invalid));
    }
    expect(
      decodeContactRequest({
        ..._raw(),
        'email': "a+b.o'neil@example-domain.com",
      }, requestId).email,
      "a+b.o'neil@example-domain.com",
    );
  });
  test('server list is bounded and uses stable createdAt/document ID cursor scoped to UID', () async {
    final database = _Database();
    database.pages.add([for (var i = 100; i > 50; i--) _raw(id: _id(i))]);
    database.pages.add([_raw(id: _id(50))]);
    final repository = FirestoreInboxRepository(
      firestore: database,
      ownerUid: 'a',
      isActive: () => true,
    );
    final first = await repository.list();
    expect(first.requests, hasLength(50));
    expect(first.nextCursor!.ownerUid, 'a');
    expect(first.nextCursor!.requestId, _id(51));
    final second = await repository.list(after: first.nextCursor);
    expect(second.requests.single.requestId, _id(50));
    expect(second.nextCursor, isNull);
    expect(database.paths, [
      'accounts/a/contactRequests',
      'accounts/a/contactRequests',
    ]);
    for (final query in database.queries) {
      expect(query.orders, [('createdAt', true), (FieldPath.documentId, true)]);
      expect(query.requestedLimit, 50);
      expect(query.sources, [Source.server]);
    }
    expect(database.queries.last.cursor, [
      Timestamp.fromDate(first.nextCursor!.createdAt),
      _id(51),
    ]);
    await expectLater(
      repository.list(
        after: InboxCursor(
          ownerUid: 'b',
          createdAt: DateTime.utc(2026),
          requestId: requestId,
        ),
      ),
      throwsA(_invalid),
    );
    expect(database.queries, hasLength(2));
  });
  test('server get and transaction acknowledge only readAt, repeated read leaves original timestamp', () async {
    final database = _Database()..documents[requestId] = _raw();
    final repository = FirestoreInboxRepository(
      firestore: database,
      ownerUid: 'a',
      isActive: () => true,
    );
    expect((await repository.get(requestId))!.unread, isTrue);
    final read = await repository.markRead(requestId);
    expect(read.unread, isFalse);
    expect(database.writes, hasLength(1));
    expect(database.writes.single, {'readAt': FieldValue.serverTimestamp()});
    expect(database.documents[requestId], {
      ..._raw(),
      'readAt': Timestamp.fromDate(read.readAt!),
    });
    expect(database.getSources, [Source.server, Source.server]);
    final repeated = await repository.markRead(requestId);
    expect(repeated.readAt, read.readAt);
    expect(database.writes, hasLength(1));
  });
  test('late server response after UID change and inactive write are rejected without publishing or writing', () async {
    final database = _Database();
    var active = true;
    final response = Completer<void>();
    database.beforeGet = () => response.future;
    database.documents[requestId] = _raw();
    final repository = FirestoreInboxRepository(
      firestore: database,
      ownerUid: 'a',
      isActive: () => active,
    );
    final reading = repository.get(requestId);
    active = false;
    response.complete();
    await expectLater(
      reading,
      throwsA(
        isA<InboxFailure>().having(
          (e) => e.kind,
          'kind',
          InboxFailureKind.unauthenticated,
        ),
      ),
    );
    await expectLater(
      repository.markRead(requestId),
      throwsA(
        isA<InboxFailure>().having(
          (e) => e.kind,
          'kind',
          InboxFailureKind.unauthenticated,
        ),
      ),
    );
    expect(database.writes, isEmpty);
  });
  test('server failures expose retryable network and owner permission denial without cache fallback', () async {
    final database = _Database()
      ..failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
    final repository = FirestoreInboxRepository(
      firestore: database,
      ownerUid: 'a',
      isActive: () => true,
    );
    await expectLater(
      repository.get(requestId),
      throwsA(
        isA<InboxFailure>().having(
          (e) => e.kind,
          'kind',
          InboxFailureKind.network,
        ),
      ),
    );
    database.failure = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    await expectLater(
      repository.list(),
      throwsA(
        isA<InboxFailure>().having(
          (e) => e.kind,
          'kind',
          InboxFailureKind.permissionDenied,
        ),
      ),
    );
    expect(database.getSources, [Source.server]);
  });
}

class _Database extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  final pages = <List<Map<String, dynamic>>>[];
  final paths = <String>[], queries = <_Query>[];
  final getSources = <Source>[], writes = <Map<String, dynamic>>[];
  Object? failure;
  Future<void> Function()? beforeGet;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    paths.add(path);
    final query = _Query(this);
    queries.add(query);
    return query;
  }

  Future<void> get() async {
    await beforeGet?.call();
    if (failure != null) {
      throw failure!;
    }
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async => transactionHandler(_Transaction(this));
}

// SDK double проверяет вызовы настоящего адаптера; native acceptance проверяет реальные SDK/Rules.
// ignore: subtype_of_sealed_class, must_be_immutable
class _Query extends Fake implements CollectionReference<Map<String, dynamic>> {
  _Query(this.database);
  final _Database database;
  final orders = <(Object, bool)>[], sources = <Source>[];
  int? requestedLimit;
  List<Object?>? cursor;
  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    orders.add((field, descending));
    return this;
  }

  @override
  Query<Map<String, dynamic>> limit(int limit) {
    requestedLimit = limit;
    return this;
  }

  @override
  Query<Map<String, dynamic>> startAfter(Iterable<Object?> values) {
    cursor = values.toList();
    return this;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    sources.add(options!.source);
    await database.get();
    return _Page(database.pages.removeAt(0));
  }

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(database, path!);
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.database, this.id);
  final _Database database;
  @override
  final String id;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    database.getSources.add(options!.source);
    await database.get();
    return _Snapshot(id, database.documents[id]);
  }
}

// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
}

// ignore: subtype_of_sealed_class
class _QueryDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryDocument(this.value);
  final Map<String, dynamic> value;
  @override
  String get id => value['requestId'] as String;
  @override
  Map<String, dynamic> data() => value;
}

class _Page extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Page(List<Map<String, dynamic>> values)
    : docs = values.map(_QueryDocument.new).toList();
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.database);
  final _Database database;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async {
    await database.get();
    return _Snapshot(ref.id, database.documents[ref.id]) as DocumentSnapshot<T>;
  }

  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    database.writes.add(Map<String, dynamic>.from(data));
    database.documents[reference.id] = {
      ...database.documents[reference.id]!,
      'readAt': Timestamp.fromDate(DateTime.utc(2026, 10, 10)),
    };
    return this;
  }
}
