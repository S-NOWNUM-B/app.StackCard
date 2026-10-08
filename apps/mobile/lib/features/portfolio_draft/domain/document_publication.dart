enum DocumentPublicationVisibility { published, unpublished, deleted }

enum DocumentPublicationAction { publish, unpublish, deleteDocument }

enum DocumentPublicationOutcome { completed, pending, unknown }

enum DocumentPublicationFailureKind {
  unavailable,
  unauthenticated,
  invalidData,
  conflict,
  deleted,
  accountDeleting,
  configurationRequired,
  reauthenticationRequired,
  unknown,
  storage,
}

final class DocumentPublicationFailure implements Exception {
  const DocumentPublicationFailure(this.kind);
  final DocumentPublicationFailureKind kind;
}

/// Только подтверждённый сервером inventory; private ID не является public URL.
final class DocumentPublication {
  const DocumentPublication({
    required this.documentId,
    required this.publicId,
    required this.version,
    required this.visibility,
    required this.sourceMutationId,
    this.url,
  });

  final String documentId;
  final String publicId;
  final int version;
  final DocumentPublicationVisibility visibility;
  final String sourceMutationId;
  final Uri? url;

  Uri? get shareableUrl =>
      visibility == DocumentPublicationVisibility.published ? url : null;
}

final class DocumentPublicationInventory {
  DocumentPublicationInventory({
    required Iterable<DocumentPublication> publications,
    required this.lifecycleGeneration,
  }) : publications = List.unmodifiable(publications);

  final List<DocumentPublication> publications;
  final int lifecycleGeneration;

  DocumentPublication? forDocument(String id) =>
      publications.where((item) => item.documentId == id).firstOrNull;
}

/// Сохраняется до POST; retry повторяет именно этот idempotent запрос.
final class DocumentPublicationMutation {
  const DocumentPublicationMutation({
    required this.action,
    required this.operationId,
    required this.documentId,
    required this.expectedMutationId,
    required this.expectedVersion,
    required this.expectedGeneration,
  });

  final DocumentPublicationAction action;
  final String operationId;
  final String documentId;
  final String? expectedMutationId;
  final int expectedVersion;
  final int expectedGeneration;

  Map<String, Object> toJson() => {
    'action': action.name,
    'operationId': operationId,
    'documentId': documentId,
    'expectedMutationId': ?expectedMutationId,
    'expectedVersion': expectedVersion,
    'expectedGeneration': expectedGeneration,
  };

  static DocumentPublicationMutation fromJson(Map<String, dynamic> value) {
    final action = DocumentPublicationAction.values
        .where((item) => item.name == value['action'])
        .firstOrNull;
    if (action == null ||
        value['operationId'] is! String ||
        (value['operationId'] as String).isEmpty ||
        value['documentId'] is! String ||
        (value['documentId'] as String).isEmpty ||
        (value['expectedMutationId'] != null &&
            (value['expectedMutationId'] is! String ||
                (value['expectedMutationId'] as String).isEmpty)) ||
        (action == DocumentPublicationAction.publish &&
            value['expectedMutationId'] == null) ||
        value['expectedVersion'] is! int ||
        (value['expectedVersion'] as int) < 0 ||
        value['expectedGeneration'] is! int ||
        (value['expectedGeneration'] as int) < 0) {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.storage,
      );
    }
    return DocumentPublicationMutation(
      action: action,
      operationId: value['operationId'] as String,
      documentId: value['documentId'] as String,
      expectedMutationId: value['expectedMutationId'] as String?,
      expectedVersion: value['expectedVersion'] as int,
      expectedGeneration: value['expectedGeneration'] as int,
    );
  }
}

final class DocumentPublicationOperation {
  const DocumentPublicationOperation({
    required this.outcome,
    required this.operationId,
    this.action,
    this.publication,
    this.lifecycleGeneration,
  });

  final DocumentPublicationOutcome outcome;
  final String operationId;
  final String? action;
  final DocumentPublication? publication;
  final int? lifecycleGeneration;
}

abstract interface class DocumentPublicationRepository {
  Future<DocumentPublicationInventory> inventory();
  Future<DocumentPublicationOperation> status(String operationId);
  Future<DocumentPublicationOperation> mutate(
    DocumentPublicationMutation mutation,
  );
  Future<DocumentPublicationOperation> deleteAccount({
    required String operationId,
    required int expectedGeneration,
    required String recoveryKey,
  });
  Future<DocumentPublicationOperation> recoverAccountDeletion({
    required String ownerUid,
    required String operationId,
    required String recoveryKey,
    bool retry = false,
  });
}

abstract interface class DocumentPublicationOperationStore {
  Future<DocumentPublicationMutation?> read();
  Future<void> write(DocumentPublicationMutation mutation);
  Future<void> clear();
}

abstract interface class DocumentLinkActions {
  Future<void> open(Uri url);
  Future<void> share(Uri url);
}
