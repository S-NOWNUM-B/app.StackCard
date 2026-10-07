import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import 'data/native_portfolio_image_picker.dart';
import 'domain/portfolio_media.dart';

final portfolioImagePickerProvider = Provider<PortfolioImagePicker>(
  (ref) => NativePortfolioImagePicker(),
);

final portfolioMediaRepositoryFactoryProvider =
    Provider<PortfolioMediaRepository? Function(String uid)>(
      (ref) =>
          (_) => null,
    );

final portfolioMediaRepositoryProvider = Provider<PortfolioMediaRepository?>((
  ref,
) {
  if (ref.watch(accountAuthRepositoryProvider) == null) return null;
  final session = ref.watch(
    accountSessionProvider.select(
      (session) => (
        ready: session.hasValue && !session.isLoading && !session.hasError,
        uid: !session.isLoading && !session.hasError
            ? session.value?.uid
            : null,
      ),
    ),
  );
  final uid = session.uid;
  if (!session.ready || uid == null) return null;
  final repository = ref.watch(portfolioMediaRepositoryFactoryProvider)(uid);
  if (repository == null || repository.ownerUid != uid) return null;
  final guarded = _SessionMediaRepository(repository);
  ref.onDispose(() => guarded.dispose().ignore());
  return guarded;
});

/// Memory-only cache, invalidated whenever account session or repository changes.
final portfolioMediaBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, path) async {
      final repository = ref.watch(portfolioMediaRepositoryProvider);
      if (repository == null) {
        throw const PortfolioMediaFailure(
          PortfolioMediaFailureKind.unauthenticated,
        );
      }
      if (!isPortfolioMediaPathForOwner(path, repository.ownerUid)) {
        throw const PortfolioMediaFailure(
          PortfolioMediaFailureKind.permissionDenied,
        );
      }
      var active = true;
      ref.onDispose(() => active = false);
      final bytes = await repository.read(path);
      if (!active) {
        throw const PortfolioMediaFailure(
          PortfolioMediaFailureKind.unauthenticated,
        );
      }
      return Uint8List.fromList(bytes).asUnmodifiableView();
    }, retry: (_, _) => null);

final class _SessionMediaRepository
    implements PortfolioMediaRepository, PortfolioMediaRepositoryLifecycle {
  _SessionMediaRepository(this._repository);

  final PortfolioMediaRepository _repository;
  bool _active = true;

  @override
  String get ownerUid => _repository.ownerUid;

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
    _ensureActive();
    final path = await _repository.upload(
      image,
      onProgress: (progress) {
        if (_active) onProgress(progress);
      },
    );
    if (!_active) {
      try {
        await _repository.delete(path).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Guarded SDK может отказать после смены UID; draft не получает stale path.
      }
      _ensureActive();
    }
    _ensurePath(path);
    return path;
  }

  @override
  Future<Uint8List> read(String path) async {
    _ensurePath(path);
    final bytes = await _repository.read(path);
    _ensureActive();
    return bytes;
  }

  @override
  Future<void> delete(String path) async {
    _ensurePath(path);
    await _repository.delete(path);
    _ensureActive();
  }

  @override
  Future<void> dispose() async {
    if (!_active) return;
    _active = false;
    final repository = _repository;
    if (repository is PortfolioMediaRepositoryLifecycle) {
      await (repository as PortfolioMediaRepositoryLifecycle).dispose();
    }
  }
}
