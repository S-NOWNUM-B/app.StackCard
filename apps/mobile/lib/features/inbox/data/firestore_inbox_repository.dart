import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/contact_request.dart';

/// Каждый await проверяет captured UID; cache не подменяет серверный Inbox.
final class FirestoreInboxRepository implements InboxRepository {
  FirestoreInboxRepository({
    required this.firestore,
    required this.ownerUid,
    required this.isActive,
  });
  final FirebaseFirestore firestore;
  @override
  final String ownerUid;
  final bool Function() isActive;
  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection('accounts/$ownerUid/contactRequests');
  void _guard() {
    if (ownerUid.isEmpty || ownerUid.contains('/') || !isActive()) {
      throw const InboxFailure(InboxFailureKind.unauthenticated);
    }
  }

  void _id(String id) {
    _guard();
    if (!isContactRequestId(id)) {
      throw const InboxFailure(InboxFailureKind.invalidData);
    }
  }

  @override
  Future<InboxPage> list({InboxCursor? after}) async {
    _guard();
    if (after != null &&
        (after.ownerUid != ownerUid || !isContactRequestId(after.requestId))) {
      throw const InboxFailure(InboxFailureKind.invalidData);
    }
    try {
      Query<Map<String, dynamic>> query = _collection
          .orderBy('createdAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(50);
      if (after != null) {
        query = query.startAfter([
          Timestamp.fromDate(after.createdAt),
          after.requestId,
        ]);
      }
      final snapshot = await query.get(const GetOptions(source: Source.server));
      _guard();
      final items = snapshot.docs
          .map((doc) => decodeContactRequest(doc.data(), doc.id))
          .toList();
      if (items.length > 50 ||
          items.map((r) => r.requestId).toSet().length != items.length) {
        throw const InboxFailure(InboxFailureKind.invalidData);
      }
      return InboxPage(
        requests: items,
        nextCursor: items.length == 50
            ? InboxCursor(
                ownerUid: ownerUid,
                createdAt: items.last.createdAt,
                requestId: items.last.requestId,
              )
            : null,
      );
    } on FirebaseException catch (error) {
      throw inboxFailureFromFirebase(error);
    }
  }

  @override
  Future<ContactRequest?> get(String requestId) async {
    _id(requestId);
    try {
      final snapshot = await _collection
          .doc(requestId)
          .get(const GetOptions(source: Source.server));
      _guard();
      return snapshot.exists
          ? decodeContactRequest(snapshot.data(), requestId)
          : null;
    } on FirebaseException catch (error) {
      throw inboxFailureFromFirebase(error);
    }
  }

  @override
  Future<ContactRequest> markRead(String requestId) async {
    _id(requestId);
    try {
      final ref = _collection.doc(requestId);
      await firestore.runTransaction<void>((transaction) async {
        _guard();
        final snapshot = await transaction.get(ref);
        _guard();
        final request = decodeContactRequest(snapshot.data(), requestId);
        if (request.unread) {
          transaction.update(ref, {'readAt': FieldValue.serverTimestamp()});
        }
      });
      _guard();
      final result = await get(requestId);
      if (result == null || result.unread) {
        throw const InboxFailure(InboxFailureKind.invalidData);
      }
      return result;
    } on FirebaseException catch (error) {
      throw inboxFailureFromFirebase(error);
    }
  }
}

ContactRequest decodeContactRequest(Object? raw, String expectedId) {
  const keys = {
    'schemaVersion',
    'requestId',
    'publicId',
    'documentId',
    'documentTitle',
    'name',
    'email',
    'message',
    'createdAt',
    'readAt',
  };
  if (raw is! Map ||
      raw.length != keys.length ||
      !keys.containsAll(raw.keys) ||
      raw['schemaVersion'] != 1 ||
      raw['schemaVersion'] is! int ||
      raw['requestId'] != expectedId ||
      !isContactRequestId(expectedId) ||
      raw['publicId'] is! String ||
      !isContactRequestId(raw['publicId'] as String) ||
      raw['createdAt'] is! Timestamp ||
      (raw['readAt'] != null && raw['readAt'] is! Timestamp)) {
    throw const InboxFailure(InboxFailureKind.invalidData);
  }
  String text(String key, int max, {bool normalized = true}) {
    final value = raw[key];
    if (value is! String ||
        value.trim().isEmpty ||
        (normalized && (value.trim() != value || value.contains('\r'))) ||
        value.length > max ||
        RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(value)) {
      throw const InboxFailure(InboxFailureKind.invalidData);
    }
    return value;
  }

  final email = text('email', 254),
      documentId = text('documentId', 200, normalized: false);
  if (!RegExp(
        r"^[A-Za-z0-9.!$&'*+/=_^`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$",
      ).hasMatch(email) ||
      email != email.toLowerCase() ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(text('name', 100)) ||
      documentId.contains('/') ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(documentId)) {
    throw const InboxFailure(InboxFailureKind.invalidData);
  }
  final created = (raw['createdAt'] as Timestamp).toDate();
  final read = (raw['readAt'] as Timestamp?)?.toDate();
  if (read != null && read.isBefore(created)) {
    throw const InboxFailure(InboxFailureKind.invalidData);
  }
  return ContactRequest(
    requestId: expectedId,
    publicId: raw['publicId'] as String,
    documentId: documentId,
    documentTitle: text('documentTitle', 120, normalized: false),
    name: text('name', 100),
    email: email,
    message: text('message', 4000),
    createdAt: created,
    readAt: read,
  );
}

InboxFailure inboxFailureFromFirebase(FirebaseException error) =>
    InboxFailure(switch (error.code) {
      'permission-denied' => InboxFailureKind.permissionDenied,
      'unauthenticated' => InboxFailureKind.unauthenticated,
      'unavailable' || 'deadline-exceeded' => InboxFailureKind.network,
      _ => InboxFailureKind.unavailable,
    });
