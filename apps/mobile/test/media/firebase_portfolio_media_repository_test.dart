import 'dart:async';
import 'dart:typed_data';

import 'package:app_stackcard/features/media/media.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

Matcher _failure(PortfolioMediaFailureKind kind) => isA<PortfolioMediaFailure>()
    .having((failure) => failure.kind, 'kind', kind);

class _Snapshot extends Fake implements TaskSnapshot {
  _Snapshot({this.bytesTransferred = 0, this.totalBytes = 10});
  @override
  final int bytesTransferred;
  @override
  final int totalBytes;
}

class _Upload extends Fake implements UploadTask {
  final completion = Completer<TaskSnapshot>();
  final events = StreamController<TaskSnapshot>.broadcast();
  bool cancelled = false;

  @override
  Stream<TaskSnapshot> get snapshotEvents => events.stream;

  @override
  Future<bool> cancel() async {
    cancelled = true;
    return true;
  }

  @override
  Future<TaskSnapshot> timeout(
    Duration timeLimit, {
    FutureOr<TaskSnapshot> Function()? onTimeout,
  }) => completion.future.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<S> then<S>(
    FutureOr<S> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) => completion.future.then(onValue, onError: onError);
}

class _Reference extends Fake implements Reference {
  _Reference(this.fullPath);
  @override
  final String fullPath;
  _Upload? upload;
  Uint8List? uploadedBytes;
  SettableMetadata? metadata;
  Uint8List? bytes;
  int? maxBytes;
  Completer<Uint8List?>? readCompletion;
  Object? failure;
  int deletions = 0;

  @override
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    if (failure != null) throw failure!;
    uploadedBytes = data;
    this.metadata = metadata;
    return upload = _Upload();
  }

  @override
  Future<Uint8List?> getData([int maxSize = 10485760]) async {
    maxBytes = maxSize;
    if (failure != null) throw failure!;
    return readCompletion?.future ?? bytes;
  }

  @override
  Future<void> delete() async {
    deletions++;
    if (failure != null) throw failure!;
  }
}

class _Storage extends Fake implements FirebaseStorage {
  final references = <String, _Reference>{};
  @override
  Reference ref([String? path]) =>
      references.putIfAbsent(path!, () => _Reference(path));
}

Future<_Reference> _started(_Storage storage) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (storage.references.isNotEmpty &&
        storage.references.values.last.upload != null) {
      return storage.references.values.last;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('Upload did not start');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  late FirebasePortfolioMediaRepository repository;
  late PreparedPortfolioImage prepared;
  const path = 'accounts/owner/media/0123456789abcdef0123456789abcdef.jpg';

  setUp(() {
    storage = _Storage();
    repository = FirebasePortfolioMediaRepository(
      storage: storage,
      ownerUid: 'owner',
    );
    prepared = PreparedPortfolioImage(
      image.encodeJpg(image.Image(width: 2, height: 2)),
    );
  });
  tearDown(() async {
    await repository.dispose();
    for (final reference in storage.references.values) {
      await reference.upload?.events.close();
    }
  });

  test(
    'Upload uses a new owner path, JPEG metadata and safe progress',
    () async {
      final progress = <double>[];
      final uploaded = repository.upload(prepared, onProgress: progress.add);
      final reference = await _started(storage);
      expect(isPortfolioMediaPathForOwner(reference.fullPath, 'owner'), isTrue);
      expect(reference.metadata?.contentType, 'image/jpeg');
      expect(reference.metadata?.cacheControl, 'private, no-store');
      reference.upload!.events.add(_Snapshot(totalBytes: 0));
      reference.upload!.events.add(_Snapshot(bytesTransferred: 5));
      await Future<void>.delayed(Duration.zero);
      reference.upload!.completion.complete(_Snapshot(bytesTransferred: 10));
      expect(await uploaded, reference.fullPath);
      expect(progress, [0, 0.5, 1]);
      expect(reference.uploadedBytes, prepared.bytes);

      final second = repository.upload(prepared, onProgress: (_) {});
      _Reference? secondReference;
      for (
        var attempt = 0;
        attempt < 200 && secondReference == null;
        attempt++
      ) {
        if (storage.references.length == 2) {
          secondReference = storage.references.values.last;
        }
        if (secondReference == null) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }
      secondReference!.upload!.completion.complete(_Snapshot());
      expect(await second, isNot(reference.fullPath));
    },
  );

  test('Forged prepared PNG never reaches Storage', () async {
    await expectLater(
      repository.upload(
        PreparedPortfolioImage(
          image.encodePng(image.Image(width: 1, height: 1)),
        ),
        onProgress: (_) {},
      ),
      throwsA(_failure(PortfolioMediaFailureKind.invalidType)),
    );
    expect(storage.references, isEmpty);
  });

  test('Read is capped, immutable and foreign paths never reach SDK', () async {
    final reference = storage.ref(path) as _Reference;
    reference.bytes = prepared.bytes;
    final bytes = await repository.read(path);
    expect(reference.maxBytes, portfolioImageMaxBytes);
    expect(bytes, prepared.bytes);
    expect(() => bytes[0] = 0, throwsUnsupportedError);
    await expectLater(
      repository.read(path.replaceFirst('owner', 'other')),
      throwsA(_failure(PortfolioMediaFailureKind.permissionDenied)),
    );
    await expectLater(
      repository.delete('gs://private-bucket/$path'),
      throwsA(_failure(PortfolioMediaFailureKind.permissionDenied)),
    );
    expect(storage.references.length, 1);
  });

  test(
    'UID transition during upload rejects stale path and cleans orphan',
    () async {
      var active = true;
      repository = FirebasePortfolioMediaRepository(
        storage: storage,
        ownerUid: 'owner',
        isActive: () => active,
      );
      final upload = repository.upload(prepared, onProgress: (_) {});
      final expectation = expectLater(
        upload,
        throwsA(_failure(PortfolioMediaFailureKind.unauthenticated)),
      );
      final reference = await _started(storage);
      active = false;
      reference.upload!.completion.complete(_Snapshot());
      await expectation;
      expect(reference.deletions, 1);
    },
  );

  test('UID transition during read rejects old private bytes', () async {
    var active = true;
    repository = FirebasePortfolioMediaRepository(
      storage: storage,
      ownerUid: 'owner',
      isActive: () => active,
    );
    final reference = storage.ref(path) as _Reference;
    reference.readCompletion = Completer<Uint8List?>();
    final reading = repository.read(path);
    final expectation = expectLater(
      reading,
      throwsA(_failure(PortfolioMediaFailureKind.unauthenticated)),
    );
    active = false;
    reference.readCompletion!.complete(prepared.bytes);
    await expectation;
  });

  test(
    'Dispose cancels tasks and late completion never returns a stale path',
    () async {
      final upload = repository.upload(prepared, onProgress: (_) {});
      final expectation = expectLater(
        upload,
        throwsA(_failure(PortfolioMediaFailureKind.unauthenticated)),
      );
      final reference = await _started(storage);
      await repository.dispose();
      expect(reference.upload!.cancelled, isTrue);
      reference.upload!.completion.complete(_Snapshot());
      await expectation;
      expect(reference.deletions, 1);
    },
  );

  test('Bounded upload timeout cancels and cleans a late success', () async {
    repository = FirebasePortfolioMediaRepository(
      storage: storage,
      ownerUid: 'owner',
      operationTimeout: const Duration(milliseconds: 20),
    );
    final upload = repository.upload(prepared, onProgress: (_) {});
    final expectation = expectLater(
      upload,
      throwsA(_failure(PortfolioMediaFailureKind.unavailable)),
    );
    final reference = await _started(storage);
    await expectation;
    expect(reference.upload!.cancelled, isTrue);
    reference.upload!.completion.complete(_Snapshot());
    await Future<void>.delayed(Duration.zero);
    expect(reference.deletions, 1);
  });

  test(
    'Firebase errors map to safe typed failure and delete is idempotent',
    () async {
      final reference = storage.ref(path) as _Reference;
      reference.failure = FirebaseException(
        plugin: 'storage',
        code: 'unauthorized',
        message: 'private raw token',
      );
      await expectLater(
        repository.read(path),
        throwsA(_failure(PortfolioMediaFailureKind.permissionDenied)),
      );
      reference.failure = FirebaseException(
        plugin: 'storage',
        code: 'object-not-found',
      );
      await repository.delete(path);
      expect(
        portfolioMediaFailureFromFirebase(reference.failure!).toString(),
        isNot(contains('token')),
      );
    },
  );
}
