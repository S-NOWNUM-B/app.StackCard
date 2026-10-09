enum InboxFailureKind {
  unavailable,
  unauthenticated,
  permissionDenied,
  invalidData,
  network,
}

final class InboxFailure implements Exception {
  const InboxFailure(this.kind);
  final InboxFailureKind kind;
}

bool isContactRequestId(String value) =>
    RegExp(r'^[0-9a-f]{32}$').hasMatch(value);

/// Email указан посетителем и не подтверждает его личность.
final class ContactRequest {
  ContactRequest({
    required this.requestId,
    required this.publicId,
    required this.documentId,
    required this.documentTitle,
    required this.name,
    required this.email,
    required this.message,
    required DateTime createdAt,
    DateTime? readAt,
  }) : createdAt = createdAt.toUtc(),
       readAt = readAt?.toUtc();
  final String requestId,
      publicId,
      documentId,
      documentTitle,
      name,
      email,
      message;
  final DateTime createdAt;
  final DateTime? readAt;
  bool get unread => readAt == null;
}

final class InboxCursor {
  const InboxCursor({
    required this.ownerUid,
    required this.createdAt,
    required this.requestId,
  });
  final String ownerUid, requestId;
  final DateTime createdAt;
}

final class InboxPage {
  InboxPage({required List<ContactRequest> requests, this.nextCursor})
    : requests = List.unmodifiable(requests);
  final List<ContactRequest> requests;
  final InboxCursor? nextCursor;
}

abstract interface class InboxRepository {
  String get ownerUid;
  Future<InboxPage> list({InboxCursor? after});
  Future<ContactRequest?> get(String requestId);
  Future<ContactRequest> markRead(String requestId);
}
