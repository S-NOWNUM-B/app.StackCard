import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../domain/portfolio_media.dart';
import 'portfolio_image_processor.dart';

final class FirebasePortfolioMediaRepository
    implements PortfolioMediaRepository, PortfolioMediaRepositoryLifecycle {
  FirebasePortfolioMediaRepository({
    required this._storage,
    required this.ownerUid,
    this._isActive,
    this._operationTimeout = const Duration(seconds: 60),
  }) {
    if (ownerUid.isEmpty || ownerUid.contains('/')) {
      throw ArgumentError.value(ownerUid, 'ownerUid');
    }
  }

  final FirebaseStorage _storage;
  final bool Function()? _isActive;
  final Duration _operationTimeout;
  final _uploads = <UploadTask>{};
  final _processor = const PortfolioImageProcessor();
  bool _disposed = false;

  @override
  final String ownerUid;

  bool get _active => !_disposed && (_isActive?.call() ?? true);

  void _ensureActive() {
    if (!_active) {
      throw const PortfolioMediaFailure(
        PortfolioMediaFailureKind.unauthenticated,
      );
    }
  }

  void _ensurePath(String path) {
    _ensureActive();
    if (!isPortfolioMediaPathForOwner(path, ownerUid)) {
      throw const PortfolioMediaFailure(
        PortfolioMediaFailureKind.permissionDenied,
      );
    }
  }

  @override
  Future<String> upload(
    PreparedPortfolioImage image, {
    required void Function(double) onProgress,
  }) async {
    UploadTask? task;
    StreamSubscription<TaskSnapshot>? subscription;
    Reference? reference;
    var completed = false;
    try {
      _ensureActive();
      await _processor.validatePrepared(image.bytes);
      _ensureActive();
      reference = _storage.ref('accounts/$ownerUid/media/${_newImageId()}.jpg');
      onProgress(0);
      _ensureActive();
      task = reference.putData(
        image.bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'private, no-store',
        ),
      );
      _uploads.add(task);
      subscription = task.snapshotEvents.listen(
        (snapshot) {
          if (!_active || snapshot.totalBytes <= 0) return;
          onProgress(
            (snapshot.bytesTransferred / snapshot.totalBytes).clamp(0, 1),
          );
        },
        // Ошибку также получает task Future; stream не создаёт unhandled error.
        onError: (Object _) {},
      );
      await task.timeout(_operationTimeout);
      completed = true;
      if (!_active) {
        // Только собственный новый UUID; старый content никогда не изменяется.
        await _deleteOrphan(reference);
        _ensureActive();
      }
      onProgress(1);
      _ensureActive();
      return reference.fullPath;
    } catch (error) {
      if (task != null && !completed) {
        final uploadedReference = reference;
        if (uploadedReference != null) {
          // Если SDK завершит upload после timeout/cancel, удалить новый orphan.
          task
              .then<void>(
                (_) => _deleteOrphan(uploadedReference),
                onError: (Object _) {},
              )
              .ignore();
        }
        await _cancel(task);
      }
      throw portfolioMediaFailureFromFirebase(error);
    } finally {
      if (task != null) _uploads.remove(task);
      await subscription?.cancel();
    }
  }

  @override
  Future<Uint8List> read(String path) async {
    try {
      _ensurePath(path);
      final bytes = await _storage
          .ref(path)
          .getData(portfolioImageMaxBytes)
          .timeout(_operationTimeout);
      _ensureActive();
      if (bytes == null || bytes.isEmpty) {
        throw const PortfolioMediaFailure(
          PortfolioMediaFailureKind.invalidImage,
        );
      }
      await _processor.validatePrepared(bytes);
      _ensureActive();
      return Uint8List.fromList(bytes).asUnmodifiableView();
    } catch (error) {
      throw portfolioMediaFailureFromFirebase(error);
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      _ensurePath(path);
      await _storage.ref(path).delete().timeout(_operationTimeout);
      _ensureActive();
    } catch (error) {
      if (error is FirebaseException && error.code == 'object-not-found') {
        _ensureActive();
        return;
      }
      throw portfolioMediaFailureFromFirebase(error);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait(_uploads.toList().map(_cancel));
    _uploads.clear();
  }

  Future<void> _cancel(UploadTask task) async {
    try {
      await task.cancel().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Late completion игнорируется; stale UID не получает URL/path результата.
    }
  }

  Future<void> _deleteOrphan(Reference reference) async {
    try {
      await reference.delete().timeout(const Duration(seconds: 5));
    } catch (_) {
      // После sign out Rules могут отказать; файл остаётся приватным старому UID.
    }
  }
}

String _newImageId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

PortfolioMediaFailure portfolioMediaFailureFromFirebase(Object error) {
  if (error is PortfolioMediaFailure) return error;
  if (error is FirebaseException) {
    return PortfolioMediaFailure(switch (error.code) {
      'unauthorized' ||
      'permission-denied' => PortfolioMediaFailureKind.permissionDenied,
      'unauthenticated' => PortfolioMediaFailureKind.unauthenticated,
      'download-size-exceeded' => PortfolioMediaFailureKind.tooLarge,
      _ => PortfolioMediaFailureKind.unavailable,
    });
  }
  return const PortfolioMediaFailure(PortfolioMediaFailureKind.unavailable);
}
