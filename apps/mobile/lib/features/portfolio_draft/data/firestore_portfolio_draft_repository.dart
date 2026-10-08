import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/portfolio_draft_repository.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_sync.dart';
import '../domain/portfolio_validation.dart';
import 'portfolio_content_codec.dart';

/// Every reference and outgoing mutation belongs to the captured account UID.
final class FirestorePortfolioDraftRepository
    implements RemotePortfolioDraftRepository {
  FirestorePortfolioDraftRepository({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _firestore = firestore,
       _uid = uid,
       _document = firestore.doc('accounts/$uid/drafts/current') {
    if (uid.isEmpty || uid.contains('/')) throw ArgumentError.value(uid, 'uid');
  }

  final FirebaseFirestore _firestore;
  final String _uid;
  final DocumentReference<Map<String, dynamic>> _document;

  @override
  Stream<DraftRemoteEvent> watch() {
    try {
      return _document
          .snapshots(includeMetadataChanges: true)
          .map((snapshot) {
            final data = snapshot.data();
            return DraftRemoteEvent(
              draft: data == null
                  ? null
                  : decodeCloudPortfolioDraft(
                      data,
                      ownerUid: _uid,
                      allowUnresolvedTimestamp:
                          snapshot.metadata.hasPendingWrites,
                    ),
              fromCache: snapshot.metadata.isFromCache,
              hasPendingWrites: snapshot.metadata.hasPendingWrites,
            );
          })
          .handleError((Object error) {
            throw portfolioSyncFailureFromFirestore(error);
          });
    } catch (error) {
      return Stream.error(portfolioSyncFailureFromFirestore(error));
    }
  }

  @override
  Future<void> write(CloudPortfolioDraft draft) async {
    try {
      if (draft.ownerUid != _uid) {
        throw const PortfolioSyncFailure(
          PortfolioSyncFailureKind.permissionDenied,
        );
      }
      await _document.set(encodeCloudPortfolioDraft(draft));
    } catch (error) {
      throw portfolioSyncFailureFromFirestore(error);
    }
  }

  /// An online preflight is useful for UI, but the transaction is the final guard.
  Future<bool> hasDraftOnServer() async {
    try {
      return (await _document.get(const GetOptions(source: Source.server)))
          .exists;
    } catch (error) {
      throw portfolioSyncFailureFromFirestore(error);
    }
  }

  /// A fresh device must not replace an account's existing cloud draft.
  /// The durable transfer journal supplies the same mutation ID on every retry.
  Future<void> claimGuestDraft(CloudPortfolioDraft draft) async {
    try {
      if (draft.ownerUid != _uid) {
        throw const PortfolioSyncFailure(
          PortfolioSyncFailureKind.permissionDenied,
        );
      }
      final encoded = encodeCloudPortfolioDraft(draft);
      await _firestore.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(_document);
        final raw = snapshot.data();
        if (raw == null) {
          transaction.set(_document, encoded);
          return;
        }
        final existing = decodeCloudPortfolioDraft(raw, ownerUid: _uid);
        if (existing.mutationId == draft.mutationId &&
            existing.notes == draft.notes &&
            existing.content == draft.content) {
          return;
        }
        throw const PortfolioDraftFailure(PortfolioDraftFailureKind.conflict);
      });
    } catch (error) {
      if (error is PortfolioDraftFailure) rethrow;
      throw portfolioSyncFailureFromFirestore(error);
    }
  }
}

Map<String, dynamic> encodeCloudPortfolioDraft(CloudPortfolioDraft draft) {
  if (draft.ownerUid.isEmpty ||
      draft.ownerUid.contains('/') ||
      draft.mutationId.isEmpty ||
      draft.mutationId.length > 200 ||
      draft.localRevision < 1 ||
      (draft.content != null &&
          validatePortfolioContent(draft.content!).isNotEmpty)) {
    throw const PortfolioSyncFailure(PortfolioSyncFailureKind.invalidData);
  }
  _validateMediaOwner(draft.content, draft.ownerUid);
  return {
    'schemaVersion': 6,
    'ownerUid': draft.ownerUid,
    'mutationId': draft.mutationId,
    'localRevision': draft.localRevision,
    'notes': draft.notes,
    'content': draft.content == null
        ? null
        : encodePortfolioContent(draft.content!),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

CloudPortfolioDraft decodeCloudPortfolioDraft(
  Map<String, dynamic> data, {
  required String ownerUid,
  bool allowUnresolvedTimestamp = false,
}) {
  const fields = {
    'schemaVersion',
    'ownerUid',
    'mutationId',
    'localRevision',
    'notes',
    'content',
    'updatedAt',
  };
  final mutationId = data['mutationId'];
  final schemaVersion = data['schemaVersion'];
  final localRevision = data['localRevision'];
  final updatedAt = data['updatedAt'];
  if (data.length != fields.length ||
      !fields.containsAll(data.keys) ||
      schemaVersion is! int ||
      (schemaVersion != 1 &&
          schemaVersion != 2 &&
          schemaVersion != 3 &&
          schemaVersion != 4 &&
          schemaVersion != 5 &&
          schemaVersion != 6) ||
      ownerUid.isEmpty ||
      ownerUid.contains('/') ||
      data['ownerUid'] != ownerUid ||
      mutationId is! String ||
      mutationId.isEmpty ||
      mutationId.length > 200 ||
      localRevision is! int ||
      localRevision < 1 ||
      data['notes'] is! String ||
      (updatedAt is! Timestamp &&
          !(allowUnresolvedTimestamp && updatedAt == null))) {
    throw const PortfolioSyncFailure(PortfolioSyncFailureKind.invalidData);
  }
  try {
    final content = data['content'] == null
        ? null
        : decodePortfolioContent(
            data['content'],
            allowMedia: schemaVersion >= 3,
            allowDocuments: schemaVersion >= 4,
            allowBaseSnapshot: schemaVersion >= 5,
            allowPresentationPrivacy: schemaVersion >= 6,
          );
    _validateMediaOwner(content, ownerUid);
    return CloudPortfolioDraft(
      ownerUid: ownerUid,
      mutationId: mutationId,
      localRevision: localRevision,
      notes: data['notes'] as String,
      content: content,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  } on FormatException {
    throw const PortfolioSyncFailure(PortfolioSyncFailureKind.invalidData);
  }
}

void _validateMediaOwner(PortfolioContent? content, String ownerUid) {
  if (content == null) return;
  final prefix = 'accounts/$ownerUid/media/';
  final avatarPath = content.profile.avatarPath;
  if ((avatarPath.isNotEmpty && !avatarPath.startsWith(prefix)) ||
      content.projects.any(
        (project) => project.imagePaths.any((path) => !path.startsWith(prefix)),
      ) ||
      content.documents.any((document) {
        final snapshotPath = document.content.profile.avatarPath;
        final basePath = document.baseSnapshot?.profile.avatarPath ?? '';
        return (snapshotPath.isNotEmpty && !snapshotPath.startsWith(prefix)) ||
            (basePath.isNotEmpty && !basePath.startsWith(prefix));
      })) {
    throw const PortfolioSyncFailure(PortfolioSyncFailureKind.invalidData);
  }
}

PortfolioSyncFailure portfolioSyncFailureFromFirestore(Object error) {
  if (error is PortfolioSyncFailure) return error;
  if (error is FirebaseException) {
    return PortfolioSyncFailure(switch (error.code) {
      'permission-denied' => PortfolioSyncFailureKind.permissionDenied,
      'unauthenticated' => PortfolioSyncFailureKind.unauthenticated,
      'unavailable' ||
      'deadline-exceeded' ||
      'network-request-failed' => PortfolioSyncFailureKind.network,
      'invalid-argument' =>
        (error.message?.toLowerCase().contains('size') ?? false)
            ? PortfolioSyncFailureKind.oversized
            : PortfolioSyncFailureKind.invalidData,
      _ => PortfolioSyncFailureKind.unavailable,
    });
  }
  if (error is FormatException) {
    return const PortfolioSyncFailure(PortfolioSyncFailureKind.invalidData);
  }
  return const PortfolioSyncFailure(PortfolioSyncFailureKind.unavailable);
}
