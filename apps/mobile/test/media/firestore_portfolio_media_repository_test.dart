import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_stackcard/features/media/media.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

const _path = 'accounts/owner/media/0123456789abcdef0123456789abcdef.jpg';
Matcher _failure(PortfolioMediaFailureKind kind) => isA<PortfolioMediaFailure>()
    .having((failure) => failure.kind, 'kind', kind);

// Как в firestore_draft_adapter_test: локальная подмена sealed SDK для mapping tests.
// ignore: subtype_of_sealed_class
class _Snapshot<T extends Object?> extends Fake implements DocumentSnapshot<T> {
  _Snapshot(this.value);
  final T? value;
  @override
  bool get exists => value != null;
  @override
  T? data() => value;
}

// ignore: subtype_of_sealed_class
class _Reference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.store, this.path);
  final _Firestore store;
  @override
  final String path;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    store.readPaths.add(path);
    store.sources.add(options?.source);
    await store.pendingRead?.future;
    return _Snapshot(store.documents[path]);
  }
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.store);
  final _Firestore store;
  final writes = <String, Map<String, dynamic>?>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async {
    store.readPaths.add(reference.path);
    return _Snapshot<T>(store.documents[reference.path] as T?);
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    writes[reference.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }

  @override
  Transaction delete(DocumentReference reference) {
    writes[reference.path] = null;
    return this;
  }
}

class _Firestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  final readPaths = <String>[];
  final sources = <Source?>[];
  Completer<void>? pendingRead;
  Completer<void>? pendingCommit;
  int transactions = 0;
  @override
  DocumentReference<Map<String, dynamic>> doc(String documentPath) =>
      _Reference(this, documentPath);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    transactions++;
    final transaction = _Transaction(this),
        result = await transactionHandler(transaction);
    await pendingCommit?.future;
    for (final entry in transaction.writes.entries) {
      if (entry.value == null) {
        documents.remove(entry.key);
      } else {
        documents[entry.key] = entry.value!;
      }
    }
    return result;
  }
}

class _Legacy implements PortfolioMediaRepository {
  @override
  final ownerUid = 'owner';
  int reads = 0, deletes = 0;
  final bytes = Uint8List.fromList([1, 2, 3]);
  @override
  Future<Uint8List> read(String path) async {
    reads++;
    return bytes;
  }

  @override
  Future<void> delete(String path) async {
    deletes++;
  }

  @override
  Future<String> upload(
    PreparedPortfolioImage image, {
    required void Function(double) onProgress,
  }) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Firestore firestore;
  late FirestorePortfolioMediaRepository repository;
  late PreparedPortfolioImage prepared;
  Map<String, dynamic> document() => {
    'schemaVersion': 1,
    'contentType': 'image/jpeg',
    'base64': base64Encode(prepared.bytes),
  };
  setUp(() {
    firestore = _Firestore();
    repository = FirestorePortfolioMediaRepository(
      firestore: firestore,
      ownerUid: 'owner',
    );
    prepared = PreparedPortfolioImage(
      image.encodeJpg(image.Image(width: 2, height: 2)),
    );
  });

  test(
    'Spark upload creates exact immutable JPEG document without Storage',
    () async {
      final progress = <double>[];
      final first = await repository.upload(prepared, onProgress: progress.add);
      final second = await repository.upload(prepared, onProgress: (_) {});
      expect(isPortfolioMediaPathForOwner(first, 'owner'), isTrue);
      expect(first, isNot(second));
      expect(firestore.documents[first], document());
      expect(firestore.documents.length, 2);
      expect(progress, [0, 1]);
      expect(firestore.readPaths, contains('accounts/owner'));
    },
  );

  test(
    'Reads server bytes with exact codec, bounded payload and immutable output',
    () async {
      firestore.documents[_path] = document();
      final bytes = await repository.read(_path);
      expect(bytes, prepared.bytes);
      expect(firestore.sources, [Source.server]);
      expect(() => bytes[0] = 0, throwsUnsupportedError);
      for (final bad in [
        {...document(), 'downloadToken': 'private'},
        {...document(), 'schemaVersion': 2},
        {...document(), 'contentType': 'image/png'},
        {...document(), 'base64': '${base64Encode(prepared.bytes)}\n'},
        {
          ...document(),
          'base64': 'A' * (((portfolioAvatarMaxBytes + 2) ~/ 3) * 4 + 4),
        },
        {
          ...document(),
          'base64': base64Encode(
            image.encodeJpg(image.Image(width: 513, height: 1)),
          ),
        },
      ]) {
        firestore.documents[_path] = bad;
        await expectLater(
          repository.read(_path),
          throwsA(isA<PortfolioMediaFailure>()),
        );
      }
    },
  );

  test('Foreign paths and invalid prepared images never reach SDK', () async {
    await expectLater(
      repository.read(_path.replaceFirst('owner', 'other')),
      throwsA(_failure(PortfolioMediaFailureKind.permissionDenied)),
    );
    await expectLater(
      repository.delete('$_path/child'),
      throwsA(_failure(PortfolioMediaFailureKind.permissionDenied)),
    );
    await expectLater(
      repository.upload(
        PreparedPortfolioImage(
          image.encodePng(image.Image(width: 1, height: 1)),
        ),
        onProgress: (_) {},
      ),
      throwsA(_failure(PortfolioMediaFailureKind.invalidType)),
    );
    expect(firestore.readPaths, isEmpty);
    expect(firestore.transactions, 0);
  });

  test('Only missing Firestore doc falls back; delete never deletes old Storage objects', () async {
    final legacy = _Legacy();
    repository = FirestorePortfolioMediaRepository(
      firestore: firestore,
      ownerUid: 'owner',
      legacyRepository: legacy,
    );
    expect(await repository.read(_path), legacy.bytes);
    expect(legacy.reads, 1);
    await repository.delete(_path);
    expect(legacy.deletes, 0);
    firestore.documents[_path] = {...document(), 'schemaVersion': 9};
    await expectLater(
      repository.read(_path),
      throwsA(_failure(PortfolioMediaFailureKind.invalidImage)),
    );
    expect(legacy.reads, 1);
  });

  test(
    'Account lifecycle is checked transactionally before create or delete',
    () async {
      firestore.documents['accounts/owner'] = {'lifecycleState': 'deleting'};
      await expectLater(
        repository.upload(prepared, onProgress: (_) {}),
        throwsA(_failure(PortfolioMediaFailureKind.permissionDenied)),
      );
      await expectLater(
        repository.delete(_path),
        throwsA(_failure(PortfolioMediaFailureKind.permissionDenied)),
      );
      expect(firestore.documents.keys, ['accounts/owner']);
    },
  );

  test(
    'Late read/commit cannot return private bytes or path after UID transition',
    () async {
      var active = true;
      repository = FirestorePortfolioMediaRepository(
        firestore: firestore,
        ownerUid: 'owner',
        isActive: () => active,
      );
      firestore.documents[_path] = document();
      firestore.pendingRead = Completer<void>();
      final reading = repository.read(_path);
      final readExpectation = expectLater(
        reading,
        throwsA(_failure(PortfolioMediaFailureKind.unauthenticated)),
      );
      active = false;
      firestore.pendingRead!.complete();
      await readExpectation;
      active = true;
      firestore.pendingCommit = Completer<void>();
      final upload = repository.upload(prepared, onProgress: (_) {});
      final uploadExpectation = expectLater(
        upload,
        throwsA(_failure(PortfolioMediaFailureKind.unauthenticated)),
      );
      while (firestore.transactions == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      active = false;
      firestore.pendingCommit!.complete();
      await uploadExpectation;
      expect(firestore.documents[_path], document());
    },
  );

  test('Dispose prevents new operations and late acknowledgements', () async {
    await repository.dispose();
    await expectLater(
      repository.read(_path),
      throwsA(_failure(PortfolioMediaFailureKind.unauthenticated)),
    );
    expect(firestore.readPaths, isEmpty);
  });
}
