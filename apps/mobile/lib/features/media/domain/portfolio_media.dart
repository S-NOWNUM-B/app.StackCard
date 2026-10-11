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

/// Read-only совместимость сохранённого внешнего avatar URL, без загрузки в cloud.
abstract interface class PortfolioLegacyAvatarReader {
  Future<Uint8List> read(String url);
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

/// Новый аватар помещается в ограниченный Firestore document на Spark.
/// Legacy Storage limits выше сохраняются только для чтения прежних объектов.
const portfolioAvatarMaxBytes = 256 * 1024;
const portfolioAvatarMaxDimension = 512;

bool isPortfolioMediaPathForOwner(String path, String uid) {
  if (uid.isEmpty || uid.contains('/')) return false;
  final match = RegExp(
    '^accounts/${RegExp.escape(uid)}/media/[a-f0-9]{32}\\.jpg\$',
  ).firstMatch(path);
  return match != null && match.end == path.length;
}
