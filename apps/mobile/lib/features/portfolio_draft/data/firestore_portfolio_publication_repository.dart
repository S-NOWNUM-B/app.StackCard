import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/portfolio_content.dart';
import '../domain/portfolio_publication.dart';
import '../domain/portfolio_validation.dart';
import 'firestore_portfolio_draft_repository.dart';
import 'portfolio_public_content_codec.dart';

/// Online transactions change the account pointer, claim, and snapshot together.
final class FirestorePortfolioPublicationRepository
    implements PortfolioPublicationRepository {
  FirestorePortfolioPublicationRepository({
    required this._firestore,
    required String uid,
  }) : _uid = uid {
    if (uid.isEmpty || uid.contains('/')) throw ArgumentError.value(uid, 'uid');
  }

  final FirebaseFirestore _firestore;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _account =>
      _firestore.doc('accounts/$_uid');

  @override
  Future<void> publish({
    required String username,
    required PortfolioContent content,
  }) async {
    if (username.isEmpty || validatePortfolioUsername(username) != null) {
      throw const PortfolioPublicationFailure(
        PortfolioPublicationFailureKind.invalidUsername,
      );
    }
    if (validatePortfolioContent(content).isNotEmpty) {
      throw const PortfolioPublicationFailure(
        PortfolioPublicationFailureKind.invalidContent,
      );
    }
    try {
      await _firestore.runTransaction<void>((transaction) async {
        final draftSnapshot = await transaction.get(
          _firestore.doc('accounts/$_uid/drafts/current'),
        );
        final accountSnapshot = await transaction.get(_account);
        final claimRef = _firestore.doc('usernames/$username');
        final claim = await transaction.get(claimRef);
        final account = _readAccount(accountSnapshot.data());
        final rawDraft = draftSnapshot.data();
        if (rawDraft == null) {
          throw const PortfolioPublicationFailure(
            PortfolioPublicationFailureKind.invalidContent,
          );
        }
        final draft = decodeCloudPortfolioDraft(rawDraft, ownerUid: _uid);
        if (draft.content == null || draft.content != content) {
          // A stale or unsaved editor snapshot cannot silently become public.
          throw const PortfolioPublicationFailure(
            PortfolioPublicationFailureKind.invalidContent,
          );
        }
        if (claim.exists && claim.data()?['ownerUid'] != _uid) {
          throw const PortfolioPublicationFailure(
            PortfolioPublicationFailureKind.usernameUnavailable,
          );
        }
        final version = account.version + 1;
        final oldUsername = account.username;
        if (oldUsername != null && oldUsername != username) {
          transaction.delete(_firestore.doc('publicPortfolios/$oldUsername'));
          transaction.delete(_firestore.doc('usernames/$oldUsername'));
        }
        transaction.set(claimRef, {'ownerUid': _uid, 'username': username});
        transaction.set(_firestore.doc('publicPortfolios/$username'), {
          'schemaVersion': 1,
          'ownerUid': _uid,
          'username': username,
          'publicationVersion': version,
          'sourceMutationId': draft.mutationId,
          'content': encodePublicPortfolioContent(content),
          'publishedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(_account, {
          'ownerUid': _uid,
          'username': username,
          'publicationVersion': version,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      if (error is PortfolioPublicationFailure) rethrow;
      throw portfolioSyncFailureFromFirestore(error);
    }
  }

  @override
  Future<void> unpublish() async {
    try {
      await _firestore.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(_account);
        final account = _readAccount(snapshot.data());
        final username = account.username;
        if (username == null) return;
        transaction.delete(_firestore.doc('publicPortfolios/$username'));
        transaction.delete(_firestore.doc('usernames/$username'));
        transaction.set(_account, {
          'ownerUid': _uid,
          'username': null,
          'publicationVersion': account.version + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      if (error is PortfolioPublicationFailure) rethrow;
      throw portfolioSyncFailureFromFirestore(error);
    }
  }

  _PublicationAccount _readAccount(Map<String, dynamic>? data) {
    if (data == null) return const _PublicationAccount();
    final username = data['username'];
    final version = data['publicationVersion'];
    if (data['ownerUid'] != _uid ||
        version is! int ||
        version < 1 ||
        !data.containsKey('username') ||
        (username != null &&
            (username is! String ||
                username.isEmpty ||
                validatePortfolioUsername(username) != null))) {
      throw const PortfolioPublicationFailure(
        PortfolioPublicationFailureKind.invalidRemoteState,
      );
    }
    return _PublicationAccount(username: username as String?, version: version);
  }
}

final class _PublicationAccount {
  const _PublicationAccount({this.username, this.version = 0});
  final String? username;
  final int version;
}
