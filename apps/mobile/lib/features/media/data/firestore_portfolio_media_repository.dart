import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/portfolio_media.dart';
import 'firebase_portfolio_media_repository.dart';
import 'portfolio_image_processor.dart';

/// Новый аватар на Spark: immutable owner document, без Storage/download tokens.
final class FirestorePortfolioMediaRepository
    implements PortfolioMediaRepository, PortfolioMediaRepositoryLifecycle {
  FirestorePortfolioMediaRepository({
    required this._firestore,
    required this.ownerUid,
    this._isActive,
    PortfolioMediaRepository? legacyRepository,
    Duration operationTimeout = const Duration(seconds: 40),
  }) : _legacy = legacyRepository,
       _timeout = operationTimeout {
    if (ownerUid.isEmpty || ownerUid.contains('/')) {
      throw ArgumentError.value(ownerUid, 'ownerUid');
    }
    if (legacyRepository != null && legacyRepository.ownerUid != ownerUid) {
      throw ArgumentError('Legacy repository must belong to the same owner');
    }
  }

  final FirebaseFirestore _firestore;
  final bool Function()? _isActive;
  final PortfolioMediaRepository? _legacy;
  final Duration _timeout;
  final _processor = const PortfolioImageProcessor();
  bool _disposed = false;

  @override
  final String ownerUid;

  void _ensureActive() {
    if (_disposed || !(_isActive?.call() ?? true)) {
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

  void _ensureAccount(Map<String, dynamic>? data) {
    _ensureActive();
    if (data != null && (data['lifecycleState'] ?? 'active') != 'active') {
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
    try {
      _ensureActive();
      await _processor.validatePrepared(image.bytes);
      _ensureActive();
      final random = Random.secure();
      final id = List.generate(
        16,
        (_) => random.nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      final path = 'accounts/$ownerUid/media/$id.jpg';
      final document = _firestore.doc(path);
      onProgress(0);
      _ensureActive();
      await _firestore
          .runTransaction((transaction) async {
            _ensureActive();
            final account = await transaction.get(
              _firestore.doc('accounts/$ownerUid'),
            );
            _ensureAccount(account.data());
            final existing = await transaction.get(document);
            _ensureActive();
            if (existing.exists) {
              throw const PortfolioMediaFailure(
                PortfolioMediaFailureKind.unavailable,
              );
            }
            transaction.set(document, {
              'schemaVersion': 1,
              'contentType': 'image/jpeg',
              'base64': base64Encode(image.bytes),
            });
          })
          .timeout(_timeout);
      _ensureActive();
      onProgress(1);
      _ensureActive();
      return path;
    } catch (error) {
      throw portfolioMediaFailureFromFirebase(error);
    }
  }

  @override
  Future<Uint8List> read(String path) async {
    try {
      _ensurePath(path);
      final snapshot = await _firestore
          .doc(path)
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);
      _ensureActive();
      if (!snapshot.exists) {
        final legacy = _legacy;
        if (legacy == null) {
          throw const PortfolioMediaFailure(
            PortfolioMediaFailureKind.unavailable,
          );
        }
        final bytes = await legacy.read(path).timeout(_timeout);
        _ensureActive();
        return Uint8List.fromList(bytes).asUnmodifiableView();
      }
      final bytes = decodeFirestorePortfolioImage(snapshot.data());
      await _processor.validatePrepared(bytes);
      _ensureActive();
      return bytes.asUnmodifiableView();
    } catch (error) {
      throw portfolioMediaFailureFromFirebase(error);
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      _ensurePath(path);
      // Отменённая новая загрузка может удалять только Firestore object.
      // Отсутствующий doc никогда не запускает удаление legacy Storage object.
      await _firestore
          .runTransaction((transaction) async {
            final account = await transaction.get(
              _firestore.doc('accounts/$ownerUid'),
            );
            _ensureAccount(account.data());
            final reference = _firestore.doc(path);
            final snapshot = await transaction.get(reference);
            _ensureActive();
            if (!snapshot.exists) return;
            decodeFirestorePortfolioImage(snapshot.data());
            transaction.delete(reference);
          })
          .timeout(_timeout);
      _ensureActive();
    } catch (error) {
      throw portfolioMediaFailureFromFirebase(error);
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final legacy = _legacy;
    if (legacy is PortfolioMediaRepositoryLifecycle) {
      await (legacy as PortfolioMediaRepositoryLifecycle).dispose();
    }
  }
}

/// Exact allowlist и размер проверяются до выделения памяти под decode.
Uint8List decodeFirestorePortfolioImage(Map<String, dynamic>? data) {
  const keys = {'schemaVersion', 'contentType', 'base64'};
  final encoded = data?['base64'];
  if (data == null ||
      data.length != keys.length ||
      !data.keys.toSet().containsAll(keys) ||
      data['schemaVersion'] != 1 ||
      data['contentType'] != 'image/jpeg' ||
      encoded is! String ||
      encoded.isEmpty ||
      encoded.length > ((portfolioAvatarMaxBytes + 2) ~/ 3) * 4 ||
      !RegExp(
        r'^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$',
      ).hasMatch(encoded)) {
    throw const PortfolioMediaFailure(PortfolioMediaFailureKind.invalidImage);
  }
  try {
    final bytes = base64Decode(encoded);
    if (bytes.isEmpty ||
        bytes.length > portfolioAvatarMaxBytes ||
        base64Encode(bytes) != encoded) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.invalidImage);
    }
    return bytes;
  } on PortfolioMediaFailure {
    rethrow;
  } catch (_) {
    throw const PortfolioMediaFailure(PortfolioMediaFailureKind.invalidImage);
  }
}
