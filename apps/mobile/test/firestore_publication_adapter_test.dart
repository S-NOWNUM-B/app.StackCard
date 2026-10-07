import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_publication_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_publication.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_sync.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Guest cloud transfer', () {
    test(
      'Claim creates an empty target and retry accepts the same mutation',
      () async {
        final firestore = _Firestore();
        final repository = FirestorePortfolioDraftRepository(
          firestore: firestore,
          uid: 'owner',
        );
        final draft = _transferDraft();
        await repository.claimGuestDraft(draft);
        expect(firestore.commits, 1);
        expect(
          firestore.documents[_draftPath]!['mutationId'],
          draft.mutationId,
        );
        firestore.documents[_draftPath]!['updatedAt'] = Timestamp.fromDate(
          DateTime.utc(2026, 10, 4),
        );
        await repository.claimGuestDraft(draft);
        expect(firestore.commits, 1);
      },
    );

    test('Occupied cloud draft is never replaced by a local guest', () async {
      final firestore = _Firestore()
        ..documents[_draftPath] = _draft(_content());
      final repository = FirestorePortfolioDraftRepository(
        firestore: firestore,
        uid: 'owner',
      );
      await expectLater(
        repository.claimGuestDraft(_transferDraft()),
        throwsA(
          isA<PortfolioDraftFailure>().having(
            (failure) => failure.kind,
            'kind',
            PortfolioDraftFailureKind.conflict,
          ),
        ),
      );
      expect(firestore.commits, 0);
      expect(firestore.documents[_draftPath]!['mutationId'], 'saved-mutation');
    });

    test('Matching transfer ID with altered content still conflicts', () async {
      final firestore = _Firestore()
        ..documents[_draftPath] = {
          ..._draft(_content()),
          'mutationId': _transferDraft().mutationId,
        };
      final repository = FirestorePortfolioDraftRepository(
        firestore: firestore,
        uid: 'owner',
      );
      await expectLater(
        repository.claimGuestDraft(_transferDraft()),
        throwsA(isA<PortfolioDraftFailure>()),
      );
      expect(firestore.commits, 0);
    });

    test('Foreign owner cannot claim even an empty target', () async {
      final firestore = _Firestore();
      final repository = FirestorePortfolioDraftRepository(
        firestore: firestore,
        uid: 'foreign',
      );
      await expectLater(
        repository.claimGuestDraft(_transferDraft()),
        throwsA(
          isA<PortfolioSyncFailure>().having(
            (failure) => failure.kind,
            'kind',
            PortfolioSyncFailureKind.permissionDenied,
          ),
        ),
      );
      expect(firestore.transactions, 0);
    });
  });
  test(
    'Publication links saved mutation, claim, account version and projection',
    () async {
      final content = _content();
      final firestore = _Firestore()..documents[_draftPath] = _draft(content);
      await _repository(firestore)
          .publish(username: 'public-name', content: content);
      expect(firestore.commits, 1);
      final account = firestore.documents[_accountPath]!;
      expect(account['username'], 'public-name');
      expect(account['publicationVersion'], 1);
      final claim = firestore.documents['usernames/public-name']!;
      expect(claim, {'ownerUid': 'owner', 'username': 'public-name'});
      final snapshot = firestore.documents['publicPortfolios/public-name']!;
      expect(snapshot['sourceMutationId'], 'saved-mutation');
      expect(snapshot['publicationVersion'], 1);
      expect(snapshot.containsKey('notes'), isFalse);
      final publicContent = decodePortfolioContent(snapshot['content']);
      expect(publicContent.profile.bio, isEmpty);
      expect(publicContent.profile.name, 'Saved profile');
      expect(firestore.documents[_draftPath]!['notes'], 'Private notes');
    },
  );

  test(
    'Stale or unsaved supplied content makes no publication writes',
    () async {
      final content = _content();
      final firestore = _Firestore()..documents[_draftPath] = _draft(content);
      await expectLater(
        _repository(firestore).publish(
          username: 'public-name',
          content: content.copyWith(resumeText: 'Unsaved change'),
        ),
        throwsA(_failure(PortfolioPublicationFailureKind.invalidContent)),
      );
      expect(firestore.commits, 0);
      expect(firestore.documents.keys, [_draftPath]);
    },
  );

  test(
    'Missing saved content and occupied username fail without writes',
    () async {
      final content = _content();
      final firestore = _Firestore();
      await expectLater(
        _repository(firestore)
            .publish(username: 'public-name', content: content),
        throwsA(_failure(PortfolioPublicationFailureKind.invalidContent)),
      );
      firestore.documents[_draftPath] = _draft(content);
      firestore.documents['usernames/public-name'] = {
        'ownerUid': 'another',
        'username': 'public-name',
      };
      await expectLater(
        _repository(firestore)
            .publish(username: 'public-name', content: content),
        throwsA(_failure(PortfolioPublicationFailureKind.usernameUnavailable)),
      );
      expect(firestore.commits, 0);
      expect(firestore.documents.containsKey(_accountPath), isFalse);
    },
  );

  test(
    'Rename releases both old documents and increments version in one commit',
    () async {
      final content = _content();
      final firestore = _Firestore()..documents[_draftPath] = _draft(content);
      final repository = _repository(firestore);
      await repository.publish(username: 'old-name', content: content);
      await repository.publish(username: 'new-name', content: content);
      expect(firestore.commits, 2);
      expect(
        firestore.documents.containsKey('publicPortfolios/old-name'),
        isFalse,
      );
      expect(firestore.documents.containsKey('usernames/old-name'), isFalse);
      expect(firestore.documents[_accountPath]!['username'], 'new-name');
      expect(firestore.documents[_accountPath]!['publicationVersion'], 2);
      expect(
        firestore.documents['publicPortfolios/new-name']!['publicationVersion'],
        2,
      );
    },
  );

  test(
    'Unpublish releases claim and snapshot while retaining private draft',
    () async {
      final content = _content();
      final firestore = _Firestore()..documents[_draftPath] = _draft(content);
      final repository = _repository(firestore);
      await repository.publish(username: 'public-name', content: content);
      await repository.unpublish();
      expect(firestore.commits, 2);
      expect(
        firestore.documents.containsKey('publicPortfolios/public-name'),
        isFalse,
      );
      expect(firestore.documents.containsKey('usernames/public-name'), isFalse);
      expect(firestore.documents[_accountPath]!['username'], isNull);
      expect(firestore.documents[_accountPath]!['publicationVersion'], 2);
      expect(firestore.documents[_draftPath]!['notes'], 'Private notes');
      await repository.unpublish();
      expect(firestore.commits, 2);
    },
  );

  test('Invalid username is rejected before database access', () async {
    final firestore = _Firestore();
    for (final username in ['', 'a_b', 'abc-', '-abc', 'Upper', 'x' * 31]) {
      await expectLater(
        _repository(firestore).publish(username: username, content: _content()),
        throwsA(_failure(PortfolioPublicationFailureKind.invalidUsername)),
        reason: username,
      );
    }
    expect(firestore.transactions, 0);
  });

  test('Publication keeps private media in the draft and excludes it from schema one', () async {
    const avatar = 'accounts/owner/media/0123456789abcdef0123456789abcdef.jpg';
    const image = 'accounts/owner/media/abcdef0123456789abcdef0123456789.jpg';
    final original = _content();
    final content = original.copyWith(
      profile: original.profile.copyWith(avatarPath: avatar),
      projects: [
        PortfolioProject(
          id: 'project',
          title: 'Project',
          description: '',
          technologies: [],
          featured: true,
          imagePaths: [image],
        ),
      ],
    );
    final firestore = _Firestore()..documents[_draftPath] = _draft(content);
    await _repository(firestore)
        .publish(username: 'public-name', content: content);
    final snapshot = firestore.documents['publicPortfolios/public-name']!;
    expect(snapshot['schemaVersion'], 1);
    final public = decodePortfolioContent(snapshot['content']);
    expect(public.profile.avatarPath, isEmpty);
    expect(public.projects.single.imagePaths, isEmpty);
    expect(
      (snapshot['content'] as Map)['profile'],
      isNot(contains('avatarPath')),
    );
    expect(
      ((snapshot['content'] as Map)['projects'] as List).single,
      isNot(contains('imagePaths')),
    );
    final private = decodeCloudPortfolioDraft(
      firestore.documents[_draftPath]!,
      ownerUid: 'owner',
    );
    expect(private.content, content);
  });

  test(
    'Malformed account pointer does not free or overwrite any documents',
    () async {
      final content = _content();
      final firestore = _Firestore()
        ..documents[_draftPath] = _draft(content)
        ..documents[_accountPath] = {
          'ownerUid': 'owner',
          'username': 'foreign/path',
          'publicationVersion': 1,
        };
      await expectLater(
        _repository(firestore)
            .publish(username: 'public-name', content: content),
        throwsA(_failure(PortfolioPublicationFailureKind.invalidRemoteState)),
      );
      expect(firestore.commits, 0);
    },
  );
}

const _draftPath = 'accounts/owner/drafts/current';
const _accountPath = 'accounts/owner';

CloudPortfolioDraft _transferDraft() => CloudPortfolioDraft(
  ownerUid: 'owner',
  mutationId: 'guest-transfer-2-4',
  localRevision: 4,
  notes: 'Guest private notes',
  content: _content(),
);

FirestorePortfolioPublicationRepository _repository(_Firestore firestore) =>
    FirestorePortfolioPublicationRepository(firestore: firestore, uid: 'owner');

Matcher _failure(PortfolioPublicationFailureKind kind) =>
    isA<PortfolioPublicationFailure>().having(
      (failure) => failure.kind,
      'kind',
      kind,
    );

PortfolioContent _content() => PortfolioContent(
  profile: const PortfolioProfile(
    name: 'Saved profile',
    bio: 'Hidden biography',
  ),
  blocks: PortfolioBlockKind.values
      .map(
        (kind) => PortfolioBlock(
          kind: kind,
          visible: kind != PortfolioBlockKind.about,
        ),
      )
      .toList(),
);

Map<String, dynamic> _draft(PortfolioContent content) => {
  'schemaVersion': 3,
  'ownerUid': 'owner',
  'mutationId': 'saved-mutation',
  'localRevision': 4,
  'notes': 'Private notes',
  'content': encodePortfolioContent(content, includeDocuments: false),
  'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 4)),
};

class _Firestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  int transactions = 0;
  int commits = 0;

  @override
  DocumentReference<Map<String, dynamic>> doc(String path) => _Reference(path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    transactions++;
    final transaction = _Transaction(this);
    final result = await transactionHandler(transaction);
    if (transaction.writes.isNotEmpty) {
      for (final entry in transaction.writes.entries) {
        final data = entry.value;
        if (data == null) {
          documents.remove(entry.key);
        } else {
          documents[entry.key] = data;
        }
      }
      commits++;
    }
    return result;
  }
}

// Unit-test SDK double; native acceptance covers real SDK objects.
// ignore: subtype_of_sealed_class
class _Reference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.path);
  @override
  final String path;
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.firestore);
  final _Firestore firestore;
  final writes = <String, Map<String, dynamic>?>{};

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async {
    if (writes.isNotEmpty) {
      throw StateError('All reads must precede all writes');
    }
    return _Snapshot<T>(firestore.documents[reference.path] as T?);
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    writes[reference.path] = Map<String, dynamic>.of(
      data as Map<String, dynamic>,
    );
    return this;
  }

  @override
  Transaction delete(DocumentReference reference) {
    writes[reference.path] = null;
    return this;
  }
}

// Unit-test SDK double; native acceptance covers real SDK objects.
// ignore: subtype_of_sealed_class
class _Snapshot<T extends Object?> extends Fake implements DocumentSnapshot<T> {
  _Snapshot(this._data);
  final T? _data;
  @override
  bool get exists => _data != null;
  @override
  T? data() => _data;
}
