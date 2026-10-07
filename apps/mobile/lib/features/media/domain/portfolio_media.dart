import 'dart:typed_data';

enum PortfolioImageSource { camera, gallery }

enum PortfolioMediaFailureKind {
  permissionDenied,
  invalidType,
  tooLarge,
  invalidImage,
  unavailable,
  unauthenticated,
}

final class PortfolioMediaFailure implements Exception {
  const PortfolioMediaFailure(this.kind);

  final PortfolioMediaFailureKind kind;

  @override
  String toString() => 'PortfolioMediaFailure(${kind.name})';
}

final class PreparedPortfolioImage {
  PreparedPortfolioImage(Uint8List bytes)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final Uint8List bytes;
}

abstract interface class PortfolioImagePicker {
  Future<PreparedPortfolioImage?> pick(PortfolioImageSource source);
}

abstract interface class PortfolioMediaRepository {
  String get ownerUid;

  Future<String> upload(
    PreparedPortfolioImage image, {
    required void Function(double) onProgress,
  });

  Future<Uint8List> read(String path);

  Future<void> delete(String path);
}

/// Опциональный lifecycle для отмены upload при смене аккаунта.
abstract interface class PortfolioMediaRepositoryLifecycle {
  Future<void> dispose();
}

const portfolioImageOriginalMaxBytes = 10 * 1024 * 1024;
const portfolioImageMaxBytes = 2 * 1024 * 1024;
const portfolioImageMaxDimension = 1600;

bool isPortfolioMediaPathForOwner(String path, String uid) {
  if (uid.isEmpty || uid.contains('/')) return false;
  final match = RegExp(
    '^accounts/${RegExp.escape(uid)}/media/[a-f0-9]{32}\\.jpg\$',
  ).firstMatch(path);
  return match != null && match.end == path.length;
}
