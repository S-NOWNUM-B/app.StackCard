import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../media/media.dart';
import '../domain/developer_card.dart';
import '../domain/document_publication.dart';
import 'developer_card_codec.dart';

/// Подписка только на anonymous-readable public snapshot. Ни чтений draft, ни writes.
final class FirestoreDeveloperCardRepository
    implements DeveloperCardRepository {
  FirestoreDeveloperCardRepository({
    required this._firestore,
    required this.ownerUid,
    required this._isActive,
    this._storage,
    this.legacyAvatarReader,
  });
  final FirebaseFirestore _firestore;
  final FirebaseStorage? _storage;
  final bool Function() _isActive;
  final PortfolioLegacyAvatarReader? legacyAvatarReader;
  @override
  final String ownerUid;

  @override
  Stream<DeveloperCard> watch(DocumentPublication publication) {
    developerCardPublicUrl(publication);
    return _firestore
        .doc('publicDocuments/${publication.publicId}')
        .snapshots(includeMetadataChanges: true)
        .asyncMap((snapshot) async {
          if (!_isActive() ||
              snapshot.metadata.isFromCache ||
              snapshot.metadata.hasPendingWrites) {
            throw const DeveloperCardFailure(
              DeveloperCardFailureKind.unavailable,
            );
          }
          if (!snapshot.exists) {
            throw const DeveloperCardFailure(
              DeveloperCardFailureKind.unpublished,
            );
          }
          final data = snapshot.data();
          // SDK Timestamp преобразуется на границе; pure codec читает wire DTO.
          final raw = data == null
              ? null
              : <String, dynamic>{
                  ...data,
                  if (data['publishedAt'] case final Timestamp timestamp)
                    'publishedAt': timestamp.toDate().toUtc().toIso8601String(),
                };
          var card = decodeDeveloperCard(raw, publication);
          var bytes = card.avatarBytes;
          if (card.avatarSource.startsWith('https:')) {
            final reader = legacyAvatarReader;
            if (reader == null) {
              throw const DeveloperCardFailure(
                DeveloperCardFailureKind.unavailable,
              );
            }
            bytes = await reader.read(card.avatarSource);
            card = decodeDeveloperCard(raw, publication, avatarBytes: bytes);
          }
          if (card.avatarSource.startsWith('publicMedia/')) {
            final storage = _storage;
            if (storage == null) {
              throw const DeveloperCardFailure(
                DeveloperCardFailureKind.unavailable,
              );
            }
            bytes = await storage
                .ref(card.avatarSource)
                .getData(portfolioImageMaxBytes)
                .timeout(const Duration(seconds: 15));
            if (bytes == null) {
              throw const DeveloperCardFailure(
                DeveloperCardFailureKind.unavailable,
              );
            }
            card = decodeDeveloperCard(raw, publication, avatarBytes: bytes);
          }
          if (bytes != null) {
            await const PortfolioImageProcessor().validatePrepared(
              bytes,
              legacy: card.avatarSource.startsWith('publicMedia/'),
            );
          }
          if (!_isActive()) {
            throw const DeveloperCardFailure(
              DeveloperCardFailureKind.unavailable,
            );
          }
          return card;
        });
  }
}
