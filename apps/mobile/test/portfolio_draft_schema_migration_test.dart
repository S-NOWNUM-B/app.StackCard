import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_github_sync.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_sync.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  final now = DateTime.utc(2026, 10, 4, 12);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'stackcard-schema-upgrade-',
    );
    box = await Hive.openBox<dynamic>('schema_upgrade', path: directory.path);
  });
  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test('V2 read is pure; explicit Save upgrades to V5 and metadata survives reopen', () async {
    final legacy = jsonEncode(_legacyEnvelope(now));
    final originalBackup = jsonEncode({
      'schemaVersion': 1,
      'notes': 'Original V1 notes',
      'revision': 2,
      'updatedAt': now.toIso8601String(),
      'pendingSync': false,
    });
    await box.put('draft', legacy);
    await box.put(HivePortfolioDraftRepository.legacyBackupKey, originalBackup);
    final repository = HivePortfolioDraftRepository(box, clock: () => now);
    final read = (await repository.read())!;
    expect(read.revision, 7);
    expect(read.notes, '  Exact legacy notes\n  ');
    expect(read.content!.projects.single.source, PortfolioProjectSource.manual);
    expect(read.content!.projects.single.githubMetadata, isNull);
    expect(read.content!.ignoredGitHubRepositories, isEmpty);
    expect(box.get('draft'), legacy);
    expect(
      box.get(HivePortfolioDraftRepository.legacyBackupKey),
      originalBackup,
    );

    final content = _importedContent(now);
    await repository.save(content, expectedRevision: 7, notes: read.notes);
    final upgraded = jsonDecode(box.get('draft') as String) as Map;
    expect(
      upgraded['schemaVersion'],
      HivePortfolioDraftRepository.schemaVersion,
    );
    expect(
      box.get(HivePortfolioDraftRepository.legacyBackupKey),
      originalBackup,
    );
    await box.close();
    box = await Hive.openBox<dynamic>('schema_upgrade', path: directory.path);
    final restored = (await HivePortfolioDraftRepository(box).read())!;
    expect(restored.content, content);
    expect(restored.content!.projects.single.githubRepositoryId, 101);
    expect(restored.content!.projects.single.lastGitHubSyncAt, now);
    expect(restored.content!.projects.single.githubMetadata!.overrideFields, {
      PortfolioGitHubField.title,
    });
    expect(
      restored.content!.ignoredGitHubRepositories.single.repositoryId,
      202,
    );
    expect(restored.notes, read.notes);
    expect(restored.revision, 8);
  });

  test(
    'Old outbox snapshot reads without migration; next metadata write uses V5',
    () async {
      final key = HivePortfolioSyncMetadataStore.storageKeyForUser('owner');
      final legacy = jsonEncode({
        'schemaVersion': 1,
        'mutationId': 'legacy-pending-mutation',
        'localRevision': 7,
        'pending': true,
        'snapshot': _legacyEnvelope(now),
      });
      await box.put(key, legacy);
      final store = HivePortfolioSyncMetadataStore(box, ownerUid: 'owner');
      final oldRecord = (await store.read())!;
      expect(
        oldRecord.draft.content!.projects.single.source,
        PortfolioProjectSource.manual,
      );
      expect(box.get(key), legacy);
      final content = _importedContent(now);
      await store.write(
        PortfolioSyncRecord(
          mutationId: 'new-pending-mutation',
          pending: true,
          draft: PortfolioDraft(
            notes: oldRecord.draft.notes,
            revision: 8,
            updatedAt: now,
            pendingSync: true,
            content: content,
          ),
        ),
      );
      final encoded = jsonDecode(box.get(key) as String) as Map;
      expect(
        (encoded['snapshot'] as Map)['schemaVersion'],
        HivePortfolioDraftRepository.schemaVersion,
      );
      await box.close();
      box = await Hive.openBox<dynamic>('schema_upgrade', path: directory.path);
      final restored = (await HivePortfolioSyncMetadataStore(
        box,
        ownerUid: 'owner',
      ).read())!;
      expect(restored.draft.content, content);
      expect(restored.mutationId, 'new-pending-mutation');
      expect(restored.pending, isTrue);
    },
  );

  test('Cloud V1 reads unchanged and V4 carries source, overrides and ignored decisions', () {
    final rawLegacy = {
      'schemaVersion': 1,
      'ownerUid': 'owner',
      'mutationId': 'legacy-cloud-mutation',
      'localRevision': 7,
      'notes': 'Private notes',
      'content': _legacyContent(),
      'updatedAt': Timestamp.fromDate(now),
    };
    final oldDraft = decodeCloudPortfolioDraft(rawLegacy, ownerUid: 'owner');
    expect(
      oldDraft.content!.projects.single.source,
      PortfolioProjectSource.manual,
    );
    expect(rawLegacy['schemaVersion'], 1);
    final content = _importedContent(now);
    final encoded = encodeCloudPortfolioDraft(
      CloudPortfolioDraft(
        ownerUid: 'owner',
        mutationId: 'github-reviewed-mutation',
        localRevision: 8,
        notes: oldDraft.notes,
        content: content,
      ),
    );
    expect(encoded['schemaVersion'], 4);
    final restored = decodeCloudPortfolioDraft({
      ...encoded,
      'updatedAt': Timestamp.fromDate(now),
    }, ownerUid: 'owner');
    expect(restored.content, content);
    expect(restored.notes, oldDraft.notes);
  });

  test(
    'Unsupported future Hive schema blocks reads and Save without losing bytes',
    () async {
      final raw = jsonEncode({
        ..._legacyEnvelope(now),
        'schemaVersion': HivePortfolioDraftRepository.schemaVersion + 1,
      });
      await box.put('draft', raw);
      final repository = HivePortfolioDraftRepository(box);
      final failure = isA<PortfolioDraftFailure>().having(
        (error) => error.kind,
        'kind',
        PortfolioDraftFailureKind.unsupportedVersion,
      );
      await expectLater(repository.read(), throwsA(failure));
      await expectLater(repository.saveNotes('Overwrite'), throwsA(failure));
      expect(box.get('draft'), raw);
    },
  );

  test('V3 content reads without eager migration and V5 media survives reopen and ACK', () async {
    final legacyContent = encodePortfolioContent(
      _importedContent(now),
      includeDocuments: false,
    );
    (legacyContent['profile'] as Map).remove('avatarPath');
    for (final item in legacyContent['projects'] as List) {
      (item as Map).remove('imagePaths');
    }
    final raw = jsonEncode({
      ..._legacyEnvelope(now),
      'schemaVersion': 3,
      'content': legacyContent,
    });
    await box.put('draft', raw);
    final repository = HivePortfolioDraftRepository(box, clock: () => now);
    final previous = (await repository.read())!;
    expect(previous.content, _importedContent(now));
    expect(previous.content!.profile.avatarPath, isEmpty);
    expect(previous.content!.projects.single.imagePaths, isEmpty);
    expect(box.get('draft'), raw);
    final content = previous.content!.copyWith(
      profile: previous.content!.profile.copyWith(avatarPath: _avatar),
      projects: [
        previous.content!.projects.single.copyWith(imagePaths: [_image]),
      ],
    );
    final saved = await repository.save(
      content,
      expectedRevision: 7,
      notes: previous.notes,
    );
    expect(
      (jsonDecode(box.get('draft') as String) as Map)['schemaVersion'],
      HivePortfolioDraftRepository.schemaVersion,
    );
    final metadata = HivePortfolioSyncMetadataStore(box, ownerUid: 'owner');
    await metadata.write(
      PortfolioSyncRecord(
        mutationId: 'media-save',
        pending: true,
        draft: saved,
      ),
    );
    await box.close();
    box = await Hive.openBox<dynamic>('schema_upgrade', path: directory.path);
    final reopened = HivePortfolioDraftRepository(box);
    expect((await reopened.read())!.content, content);
    expect(
      (await HivePortfolioSyncMetadataStore(
        box,
        ownerUid: 'owner',
      ).read())!.draft.content,
      content,
    );
    await reopened.acknowledgeRevision(saved.revision);
    expect((await reopened.read())!.content, content);
    expect((await reopened.read())!.pendingSync, isFalse);
  });

  for (final version in [2, 3]) {
    test(
      'Legacy Hive V$version rejects media fields and preserves bytes',
      () async {
        final raw = jsonEncode({
          ..._legacyEnvelope(now),
          'schemaVersion': version,
          'content': encodePortfolioContent(
            _importedContent(now)
                .copyWith(profile: const PortfolioProfile(avatarPath: _avatar)),
            includeDocuments: false,
          ),
        });
        await box.put('draft', raw);
        final repository = HivePortfolioDraftRepository(box);
        final failure = isA<PortfolioDraftFailure>().having(
          (failure) => failure.kind,
          'kind',
          PortfolioDraftFailureKind.corrupted,
        );
        await expectLater(repository.read(), throwsA(failure));
        await expectLater(repository.saveNotes('Overwrite'), throwsA(failure));
        expect(box.get('draft'), raw);
      },
    );
  }

  test(
    'Malformed V4 paths block overwrite without removing the previous record',
    () async {
      final content = _importedContent(now).copyWith(
        profile: const PortfolioProfile(
          avatarPath: 'https://example.com/download?token=secret',
        ),
      );
      final raw = jsonEncode({
        ..._legacyEnvelope(now),
        'schemaVersion': 4,
        'content': encodePortfolioContent(content, includeDocuments: false),
      });
      await box.put('draft', raw);
      final repository = HivePortfolioDraftRepository(box);
      final failure = isA<PortfolioDraftFailure>().having(
        (failure) => failure.kind,
        'kind',
        PortfolioDraftFailureKind.corrupted,
      );
      await expectLater(repository.read(), throwsA(failure));
      await expectLater(repository.saveNotes('Overwrite'), throwsA(failure));
      expect(box.get('draft'), raw);
    },
  );
}

const _avatar = 'accounts/owner/media/0123456789abcdef0123456789abcdef.jpg';
const _image = 'accounts/owner/media/abcdef0123456789abcdef0123456789.jpg';

Map<String, Object?> _legacyEnvelope(DateTime now) => {
  'schemaVersion': 2,
  'notes': '  Exact legacy notes\n  ',
  'revision': 7,
  'updatedAt': now.toIso8601String(),
  'pendingSync': true,
  'content': _legacyContent(),
};

Map<String, Object?> _legacyContent() {
  final encoded = encodePortfolioContent(
    PortfolioContent(
      projects: [
        PortfolioProject(
          id: 'legacy-manual',
          title: 'Manual project',
          description: 'Existing content',
          technologies: ['Dart'],
          featured: true,
        ),
      ],
    ),
  );
  encoded.remove('documents');
  encoded.remove('ignoredGitHubRepositories');
  (encoded['profile'] as Map).remove('avatarPath');
  for (final item in encoded['projects']! as List) {
    (item as Map).remove('source');
    item.remove('githubMetadata');
    item.remove('imagePaths');
  }
  return encoded;
}

PortfolioContent _importedContent(DateTime now) => PortfolioContent(
  projects: [
    PortfolioProject(
      id: 'github-101',
      title: 'My curated title',
      description: 'Curated description',
      technologies: ['Dart'],
      repositoryUrl: 'https://github.com/example/source-101',
      featured: true,
      source: PortfolioProjectSource.github,
      githubMetadata: GitHubProjectMetadata(
        acceptedSource: _source(101, now),
        lastGitHubSyncAt: now,
        overrideFields: {PortfolioGitHubField.title},
      ),
    ),
  ],
  ignoredGitHubRepositories: [
    GitHubIgnoredRepository(
      repositoryId: 202,
      fingerprint: _source(202, now).fingerprint,
    ),
  ],
);

GitHubProjectSource _source(int id, DateTime now) => GitHubProjectSource(
  repositoryId: id,
  name: 'source-$id',
  fullName: 'example/source-$id',
  htmlUrl: 'https://github.com/example/source-$id',
  description: 'Private original source metadata',
  language: 'Dart',
  stars: 5,
  forks: 1,
  isFork: false,
  archived: false,
  updatedAt: now,
);
