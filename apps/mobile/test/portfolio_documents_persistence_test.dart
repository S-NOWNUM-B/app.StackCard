import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart';
import 'package:app_stackcard/features/portfolio_draft/data/local_draft_accounts.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_sync.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  final now = DateTime.utc(2026, 10, 7);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stackcard-documents-');
    box = await Hive.openBox<dynamic>('documents', path: directory.path);
  });
  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });
  Future<void> reopen() async {
    await box.close();
    box = await Hive.openBox<dynamic>('documents', path: directory.path);
  }

  test(
    'documents and captured outbox survive actual Hive close/reopen',
    () async {
      final content = _workspace(now);
      final saved = await HivePortfolioDraftRepository(
        box,
        clock: () => now,
      ).save(content, expectedRevision: 0, notes: 'Private notes');
      await HivePortfolioSyncMetadataStore(box, ownerUid: 'owner').write(
        PortfolioSyncRecord(
          mutationId: 'documents-save',
          pending: true,
          draft: saved,
        ),
      );
      expect(
        (jsonDecode(box.get('draft') as String) as Map)['schemaVersion'],
        HivePortfolioDraftRepository.schemaVersion,
      );
      await reopen();
      final restored = (await HivePortfolioDraftRepository(box).read())!;
      expect(restored.content, content);
      expect(restored.notes, 'Private notes');
      expect(restored.revision, 1);
      final outbox = (await HivePortfolioSyncMetadataStore(
        box,
        ownerUid: 'owner',
      ).read())!;
      expect(outbox.draft.content, content);
      expect(outbox.mutationId, 'documents-save');
      expect(outbox.pending, isTrue);
      expect(
        await HivePortfolioDraftRepository(box).acknowledgeRevision(0),
        isNull,
      );
      await HivePortfolioDraftRepository(box).acknowledgeRevision(1);
      await reopen();
      expect(
        (await HivePortfolioDraftRepository(box).read())!.pendingSync,
        isFalse,
      );
      expect(
        (await HivePortfolioDraftRepository(box).read())!.content,
        content,
      );
    },
  );

  for (final version in [1, 2, 3, 4]) {
    test(
      'legacy V$version read stays exact; explicit Save keeps durable raw backup',
      () async {
        final raw = _legacyEnvelope(version, now);
        await box.put('draft', raw);
        final repository = HivePortfolioDraftRepository(box, clock: () => now);
        final read = (await repository.read())!;
        expect(read.content?.documents ?? [], isEmpty);
        expect(read.content?.projects.single.updatedAt, isNull);
        expect(box.get('draft'), raw);
        expect(box.keys.toList(), ['draft']);
        final content = _workspace(now);
        await repository.save(content, expectedRevision: 3, notes: read.notes);
        expect(box.get('draft.v$version.backup'), raw);
        await reopen();
        expect(box.get('draft.v$version.backup'), raw);
        expect(
          (await HivePortfolioDraftRepository(box).read())!.content,
          content,
        );
      },
    );
  }

  for (final version in [1, 2, 3, 4]) {
    test(
      'legacy V$version rejects documents key without silently downgrading',
      () async {
        final envelope =
            jsonDecode(_legacyEnvelope(version, now)) as Map<String, dynamic>;
        envelope['content'] ??= encodePortfolioContent(
          PortfolioContent(),
          includeDocuments: false,
        );
        (envelope['content'] as Map)['documents'] = [];
        final raw = jsonEncode(envelope);
        await box.put('draft', raw);
        final repository = HivePortfolioDraftRepository(box);
        await expectLater(
          repository.read(),
          throwsA(_draftFailure(PortfolioDraftFailureKind.corrupted)),
        );
        await expectLater(
          repository.saveNotes('Overwrite'),
          throwsA(_draftFailure(PortfolioDraftFailureKind.corrupted)),
        );
        expect(box.get('draft'), raw);
      },
    );

    if (version == 1) continue;
    for (final flushFailure in [false, true]) {
      test(
        'V$version ${flushFailure ? 'backup flush' : 'backup write'} failure preserves original before upgrade',
        () async {
          final raw = _legacyEnvelope(version, now);
          final key = 'draft.user.owner';
          await box.put(key, raw);
          final fault = _FaultBox(box)
            ..rejectKey = flushFailure ? null : '$key.v$version.backup'
            ..rejectFlush = flushFailure;
          final repository = HivePortfolioDraftRepository(
            fault,
            storageKey: key,
            backupKey: '$key.v1.backup',
            clock: () => now,
          );
          await expectLater(
            repository.save(
              _workspace(now),
              expectedRevision: 3,
              notes: 'New notes',
            ),
            throwsA(_draftFailure(PortfolioDraftFailureKind.unavailable)),
          );
          expect(box.get(key), raw);
          expect(fault.writes, isNot(contains(key)));
          await reopen();
          expect(box.get(key), raw);
          final read = await HivePortfolioDraftRepository(
            box,
            storageKey: key,
          ).read();
          expect(read!.content!.documents, isEmpty);
        },
      );
    }
  }

  test(
    'conflicting raw backup blocks upgrade without changing existing bytes',
    () async {
      final raw = _legacyEnvelope(4, now);
      await box.put('draft', raw);
      await box.put('draft.v4.backup', 'Another original');
      await expectLater(
        HivePortfolioDraftRepository(box)
            .save(_workspace(now), expectedRevision: 3, notes: 'New'),
        throwsA(_draftFailure(PortfolioDraftFailureKind.corrupted)),
      );
      expect(box.get('draft'), raw);
      expect(box.get('draft.v4.backup'), 'Another original');
    },
  );

  test(
    'future version cannot be overwritten by full Save or notes patch',
    () async {
      final raw = jsonEncode({
        ...jsonDecode(_legacyEnvelope(4, now)) as Map<String, dynamic>,
        'schemaVersion': HivePortfolioDraftRepository.schemaVersion + 1,
      });
      await box.put('draft', raw);
      final repository = HivePortfolioDraftRepository(box);
      await expectLater(
        repository.read(),
        throwsA(_draftFailure(PortfolioDraftFailureKind.unsupportedVersion)),
      );
      await expectLater(
        repository.saveNotes('Overwrite'),
        throwsA(_draftFailure(PortfolioDraftFailureKind.unsupportedVersion)),
      );
      await expectLater(
        repository.save(
          _workspace(now),
          expectedRevision: 3,
          notes: 'Overwrite',
        ),
        throwsA(_draftFailure(PortfolioDraftFailureKind.unsupportedVersion)),
      );
      expect(box.get('draft'), raw);
    },
  );

  test('guest document transfer recovers backup copy failure and preserves raw owner backup', () async {
    final legacy = _legacyEnvelope(4, now);
    await box.put('draft', legacy);
    final accounts = LocalDraftAccounts(box);
    await accounts.guestRepository.save(
      _workspace(now, avatarPath: ''),
      expectedRevision: 3,
      notes: 'Guest',
    );
    final current = box.get('draft');
    final ownerKey = _ownerKey('owner');
    final fault = _FaultBox(box)..rejectKey = '$ownerKey.v4.backup';
    await expectLater(
      LocalDraftAccounts(fault).transferGuestToUser('owner'),
      throwsA(_draftFailure(PortfolioDraftFailureKind.unavailable)),
    );
    expect(box.get('draft'), current);
    expect(box.get('draft.v4.backup'), legacy);
    await reopen();
    await LocalDraftAccounts(box).transferGuestToUser('owner');
    expect(box.get(ownerKey), current);
    expect(box.get('$ownerKey.v4.backup'), legacy);
    expect(box.containsKey('draft'), isFalse);
    expect(box.containsKey('draft.v4.backup'), isFalse);
    expect(
      (await LocalDraftAccounts(
        box,
      ).repositoryForUser('owner').read())!.content!.documents,
      hasLength(2),
    );
    expect(
      await LocalDraftAccounts(box).repositoryForUser('other').read(),
      isNull,
    );
  });

  test('notes-only legacy upgrade keeps content null without fabricating documents', () async {
    await box.put('draft', _legacyEnvelope(1, now));
    await HivePortfolioDraftRepository(box).saveNotes('Changed notes');
    await reopen();
    expect((await HivePortfolioDraftRepository(box).read())!.content, isNull);
  });

  test('cloud writer5 roundtrip validates every snapshot owner and legacy no-doc schemas', () {
    final workspace = _workspace(now);
    final draft = CloudPortfolioDraft(
      ownerUid: 'owner',
      mutationId: 'docs-save',
      localRevision: 1,
      notes: 'Private',
      content: workspace,
    );
    final encoded = encodeCloudPortfolioDraft(draft);
    expect(encoded['schemaVersion'], 5);
    final stored = {...encoded, 'updatedAt': Timestamp.fromDate(now)};
    expect(
      decodeCloudPortfolioDraft(stored, ownerUid: 'owner').content,
      workspace,
    );
    for (final version in [1, 2, 3]) {
      expect(
        () => decodeCloudPortfolioDraft({
          ...stored,
          'schemaVersion': version,
        }, ownerUid: 'owner'),
        throwsA(_syncFailure),
      );
    }
    expect(
      () => decodeCloudPortfolioDraft({
        ...stored,
        'schemaVersion': 6,
      }, ownerUid: 'owner'),
      throwsA(_syncFailure),
    );
    expect(
      () => decodeCloudPortfolioDraft(stored, ownerUid: 'other'),
      throwsA(_syncFailure),
    );
    final foreign = _workspace(
      now,
      avatarPath: 'accounts/other/media/0123456789abcdef0123456789abcdef.jpg',
    );
    expect(
      () => encodeCloudPortfolioDraft(
        CloudPortfolioDraft(
          ownerUid: 'owner',
          mutationId: 'foreign',
          localRevision: 1,
          notes: '',
          content: foreign,
        ),
      ),
      throwsA(_syncFailure),
    );
    final rawForeign = {...stored, 'content': encodePortfolioContent(foreign)};
    expect(
      () => decodeCloudPortfolioDraft(rawForeign, ownerUid: 'owner'),
      throwsA(_syncFailure),
    );
    for (final version in [1, 2, 3]) {
      final old =
          jsonDecode(_legacyEnvelope(version + 1, now)) as Map<String, dynamic>;
      final cloud = {
        ...stored,
        'schemaVersion': version,
        'content': old['content'],
      };
      expect(
        decodeCloudPortfolioDraft(cloud, ownerUid: 'owner').content!.documents,
        isEmpty,
      );
    }
  });
}

PortfolioContent _workspace(
  DateTime now, {
  String avatarPath =
      'accounts/owner/media/0123456789abcdef0123456789abcdef.jpg',
}) {
  final base = PortfolioContent(
    profile: const PortfolioProfile(name: 'Base profile'),
    projects: [
      PortfolioProject(
        id: 'project',
        title: 'Library',
        description: '',
        technologies: ['Dart'],
        updatedAt: now,
      ),
    ],
  );
  final snapshot = seedDocumentContent(base).copyWith(
    profile: PortfolioProfile(
      name: 'Independent profile',
      avatarPath: avatarPath,
    ),
  );
  return base.copyWith(
    documents: [
      PortfolioDocument(
        id: 'resume',
        title: 'Resume',
        kind: PortfolioDocumentKind.resume,
        createdAt: now,
        updatedAt: now,
        content: snapshot,
      ),
      PortfolioDocument(
        id: 'portfolio',
        title: 'Portfolio',
        kind: PortfolioDocumentKind.portfolio,
        createdAt: now,
        updatedAt: now,
        content: snapshot,
        projects: const [
          PortfolioProjectAttachment(projectId: 'project', featured: true),
        ],
        attachedResumeId: 'resume',
      ),
    ],
  );
}

String _legacyEnvelope(int version, DateTime now) {
  final encoded = encodePortfolioContent(
    PortfolioContent(
      projects: [
        PortfolioProject(
          id: 'project',
          title: 'Legacy library',
          description: '',
          technologies: [],
        ),
      ],
    ),
    includeDocuments: false,
  );
  if (version < 4) {
    (encoded['profile'] as Map).remove('avatarPath');
    for (final project in encoded['projects'] as List) {
      (project as Map).remove('imagePaths');
    }
  }
  if (version < 3) {
    encoded.remove('ignoredGitHubRepositories');
    for (final project in encoded['projects'] as List) {
      (project as Map).remove('source');
      project.remove('githubMetadata');
    }
  }
  return jsonEncode({
    'schemaVersion': version,
    'notes': 'Original notes',
    'revision': 3,
    'updatedAt': now.toIso8601String(),
    'pendingSync': true,
    if (version >= 2) 'content': encoded,
  });
}

String _ownerKey(String uid) =>
    'draft.user.${base64Url.encode(utf8.encode(uid)).replaceAll('=', '')}';
Matcher _draftFailure(PortfolioDraftFailureKind kind) =>
    isA<PortfolioDraftFailure>().having((error) => error.kind, 'kind', kind);
final _syncFailure = isA<PortfolioSyncFailure>().having(
  (error) => error.kind,
  'kind',
  PortfolioSyncFailureKind.invalidData,
);

final class _FaultBox implements Box<dynamic> {
  _FaultBox(this.delegate);
  final Box<dynamic> delegate;
  String? rejectKey;
  bool rejectFlush = false;
  final writes = <dynamic>[];
  @override
  bool containsKey(dynamic key) => delegate.containsKey(key);
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, dynamic value) async {
    writes.add(key);
    if (key == rejectKey) {
      throw const FileSystemException('Injected backup write failure');
    }
    await delegate.put(key, value);
  }

  @override
  Future<void> delete(dynamic key) => delegate.delete(key);
  @override
  Future<void> flush() async {
    if (rejectFlush) {
      throw const FileSystemException('Injected backup flush failure');
    }
    await delegate.flush();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
