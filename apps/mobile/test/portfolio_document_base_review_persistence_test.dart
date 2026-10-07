import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart';
import 'package:app_stackcard/features/portfolio_draft/data/local_draft_accounts.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_public_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_sync.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  final now = DateTime.utc(2026, 10, 7);
  late Directory directory;
  late Box<dynamic> box;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stackcard-base-review-');
    box = await Hive.openBox<dynamic>('base_review', path: directory.path);
  });
  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });
  Future<void> reopen() async {
    await box.close();
    box = await Hive.openBox<dynamic>('base_review', path: directory.path);
  }

  test('codec preserves captured base in only five fields and current document independently', () {
    final workspace = _workspace(now);
    final encoded = encodePortfolioContent(workspace);
    final document = (encoded['documents'] as List).single as Map;
    final baseline = document['baseSnapshot'] as Map;
    expect(baseline.keys.toSet(), {
      'profile',
      'skills',
      'experience',
      'education',
      'links',
    });
    expect((baseline['profile'] as Map)['name'], 'Сохранённая база');
    expect(decodePortfolioContent(encoded), workspace);
    expect(
      decodePortfolioContent(encoded).documents.single.content.profile.name,
      'Своё имя документа',
    );
    final legacy = _legacyContent(workspace);
    expect(
      decodePortfolioContent(legacy).documents.single.baseSnapshot,
      isNull,
    );
    expect(
      () => decodePortfolioContent(encoded, allowBaseSnapshot: false),
      throwsFormatException,
    );
    document['baseSnapshot'] = null;
    expect(
      () => decodePortfolioContent(encoded, allowBaseSnapshot: false),
      throwsFormatException,
    );
    expect(
      decodePortfolioContent(encoded).documents.single.baseSnapshot,
      isNull,
    );
  });

  test('baseline codec rejects nested workspace, unknown fields, bad values and duplicate IDs', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (base) => base['documents'] = [],
      (base) => base['projects'] = [],
      (base) => base['ignoredGitHubRepositories'] = [],
      (base) => base['theme'] = 'light',
      (base) => base['resumeText'] = 'Private text',
      (base) => base['unknown'] = true,
      (base) => base.remove('links'),
      (base) => (base['profile'] as Map)['unknown'] = true,
      (base) => (base['profile'] as Map)['avatarPath'] =
          'https://example.invalid/private',
      (base) => (base['skills'] as List).single['unknown'] = true,
      (base) => (base['skills'] as List).add((base['skills'] as List).single),
      (base) => (base['experience'] as List).single['role'] = 42,
      (base) => (base['education'] as List).single['institution'] = null,
      (base) => (base['links'] as List).single['url'] = 'javascript:alert(1)',
    ];
    for (final mutate in mutations) {
      final encoded = jsonDecode(
        jsonEncode(encodePortfolioContent(_workspace(now))),
      ) as Map<String, dynamic>;
      final document = (encoded['documents'] as List).single as Map;
      mutate(document['baseSnapshot'] as Map<String, dynamic>);
      expect(() => decodePortfolioContent(encoded), throwsFormatException);
    }
    for (final invalid in [
      _base().copyWith(
        projects: [
          PortfolioProject(
            id: 'p',
            title: 'Copied',
            description: '',
            technologies: [],
          ),
        ],
      ),
      _base().copyWith(resumeText: 'Legacy presentation'),
      _base().copyWith(theme: PortfolioTheme.light),
      _base().copyWith(
        blocks: PortfolioBlockKind.values
            .map((kind) => PortfolioBlock(kind: kind, visible: false))
            .toList(),
      ),
    ]) {
      final workspace = _workspace(now);
      expect(
        () => encodePortfolioContent(
          workspace.copyWith(
            documents: [
              workspace.documents.single.copyWith(baseSnapshot: invalid),
            ],
          ),
        ),
        throwsFormatException,
      );
    }
  });

  test('Hive6 captured outbox and newer Save survive reopen while stale ACK cannot replace baseline', () async {
    final repository = HivePortfolioDraftRepository(box, clock: () => now);
    final workspace = _workspace(now);
    final saved = await repository.save(
      workspace,
      expectedRevision: 0,
      notes: '  Exact notes\n',
    );
    final metadata = HivePortfolioSyncMetadataStore(box, ownerUid: 'owner');
    await metadata.write(
      PortfolioSyncRecord(mutationId: 'captured', pending: true, draft: saved),
    );
    final latest = workspace.copyWith(
      documents: [
        workspace.documents.single.copyWith(
          baseSnapshot: _base(name: 'Новая база'),
        ),
      ],
    );
    await repository.save(latest, expectedRevision: 1, notes: saved.notes);
    expect((jsonDecode(box.get('draft') as String) as Map)['schemaVersion'], 6);
    await reopen();
    final outbox = (await HivePortfolioSyncMetadataStore(
      box,
      ownerUid: 'owner',
    ).read())!;
    expect(outbox.draft.content, workspace);
    expect(outbox.mutationId, 'captured');
    expect(outbox.pending, isTrue);
    final reopened = HivePortfolioDraftRepository(box);
    expect(await reopened.acknowledgeRevision(1), isNull);
    expect((await reopened.read())!.content, latest);
    await reopened.acknowledgeRevision(2);
    await reopen();
    final acked = (await HivePortfolioDraftRepository(box).read())!;
    expect(acked.content, latest);
    expect(acked.notes, '  Exact notes\n');
    expect(acked.pendingSync, isFalse);
  });

  for (final operation in ['save', 'notes', 'ack']) {
    test(
      'legacy Hive5 pure read and $operation upgrade preserve exact raw backup across reopen',
      () async {
        final raw = _legacyEnvelope(_workspace(now), now);
        await box.put('draft', raw);
        final repository = HivePortfolioDraftRepository(box, clock: () => now);
        final legacy = (await repository.read())!;
        expect(legacy.content!.documents.single.baseSnapshot, isNull);
        expect(box.get('draft'), raw);
        expect(box.keys.toList(), ['draft']);
        if (operation == 'save') {
          await repository.save(
            _workspace(now),
            expectedRevision: 3,
            notes: legacy.notes,
          );
        } else if (operation == 'notes') {
          await repository.saveNotes('Only notes');
        } else {
          await repository.acknowledgeRevision(3);
        }
        await reopen();
        expect(box.get('draft.v5.backup'), raw);
        expect(
          (jsonDecode(box.get('draft') as String) as Map)['schemaVersion'],
          6,
        );
        final restored = (await HivePortfolioDraftRepository(box).read())!;
        expect(
          restored.content!.documents.single.baseSnapshot,
          operation == 'save' ? _base() : null,
        );
        expect(
          restored.content!.documents.single.content.profile.name,
          'Своё имя документа',
        );
      },
    );
  }

  for (final flushFailure in [false, true]) {
    test(
      'Hive5 backup ${flushFailure ? 'flush' : 'write'} failure preserves original envelope and blocks upgrade',
      () async {
        final raw = _legacyEnvelope(_workspace(now), now);
        await box.put('draft', raw);
        final fault = _FaultBox(box)
          ..rejectKey = flushFailure ? null : 'draft.v5.backup'
          ..rejectFlush = flushFailure;
        await expectLater(
          HivePortfolioDraftRepository(fault)
              .save(_workspace(now), expectedRevision: 3, notes: 'New'),
          throwsA(_draftFailure(PortfolioDraftFailureKind.unavailable)),
        );
        expect(box.get('draft'), raw);
        expect(fault.writes, isNot(contains('draft')));
        await reopen();
        expect(box.get('draft'), raw);
      },
    );
  }

  test('legacy Hive5 new baseline key is corruption even when null and cannot be overwritten', () async {
    for (final baseSnapshot in [
      null,
      {'profile': {}},
    ]) {
      final decoded = jsonDecode(_legacyEnvelope(_workspace(now), now)) as Map;
      ((decoded['content'] as Map)['documents'] as List)
              .single['baseSnapshot'] =
          baseSnapshot;
      final raw = jsonEncode(decoded);
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
    }
  });

  test('owner transfer carries raw Hive5 backup and baseline; retry after backup failure stays in same UID', () async {
    final workspace = _workspace(now, avatarPath: '');
    final legacy = _legacyEnvelope(workspace, now);
    await box.put('draft', legacy);
    await LocalDraftAccounts(box).guestRepository
        .save(workspace, expectedRevision: 3, notes: 'Guest');
    final current = box.get('draft');
    final ownerKey = _ownerKey('owner');
    final fault = _FaultBox(box)..rejectKey = '$ownerKey.v5.backup';
    await expectLater(
      LocalDraftAccounts(fault).transferGuestToUser('owner'),
      throwsA(_draftFailure(PortfolioDraftFailureKind.unavailable)),
    );
    expect(box.get('draft'), current);
    expect(box.get('draft.v5.backup'), legacy);
    await reopen();
    await LocalDraftAccounts(box).transferGuestToUser('owner');
    expect(box.get(ownerKey), current);
    expect(box.get('$ownerKey.v5.backup'), legacy);
    expect(box.containsKey('draft'), isFalse);
    expect(box.containsKey('draft.v5.backup'), isFalse);
    final owned = await LocalDraftAccounts(box)
        .repositoryForUser('owner')
        .read();
    expect(owned!.content, workspace);
    expect(
      await LocalDraftAccounts(box).repositoryForUser('other').read(),
      isNull,
    );
  });

  test('cloud5 roundtrip and cloud4 legacy preserve baseline null, reject downgrade metadata, future schema and foreign base media', () {
    final workspace = _workspace(now);
    final encoded = encodeCloudPortfolioDraft(
      CloudPortfolioDraft(
        ownerUid: 'owner',
        mutationId: 'base-review',
        localRevision: 1,
        notes: 'Private',
        content: workspace,
      ),
    );
    expect(encoded['schemaVersion'], 5);
    final stored = {...encoded, 'updatedAt': Timestamp.fromDate(now)};
    expect(
      decodeCloudPortfolioDraft(stored, ownerUid: 'owner').content,
      workspace,
    );
    final old = {
      ...stored,
      'schemaVersion': 4,
      'content': _legacyContent(workspace),
    };
    expect(
      decodeCloudPortfolioDraft(
        old,
        ownerUid: 'owner',
      ).content!.documents.single.baseSnapshot,
      isNull,
    );
    expect(old['schemaVersion'], 4);
    for (final version in [1, 2, 3, 4, 6]) {
      expect(
        () => decodeCloudPortfolioDraft({
          ...stored,
          'schemaVersion': version,
        }, ownerUid: 'owner'),
        throwsA(_syncFailure),
      );
    }
    final foreign = workspace.copyWith(
      documents: [
        workspace.documents.single.copyWith(
          baseSnapshot: _base(avatarPath: _foreignAvatar),
        ),
      ],
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
    expect(
      () => decodeCloudPortfolioDraft({
        ...stored,
        'content': encodePortfolioContent(foreign),
      }, ownerUid: 'owner'),
      throwsA(_syncFailure),
    );
    expect(
      () => decodeCloudPortfolioDraft(stored, ownerUid: 'other'),
      throwsA(_syncFailure),
    );
  });

  test('legacy publication projection physically excludes captured bases, documents and private paths', () {
    final workspace = _workspace(now);
    final projected = projectPublicPortfolioContent(workspace);
    expect(projected.documents, isEmpty);
    final public = encodePublicPortfolioContent(workspace);
    final raw = jsonEncode(public);
    expect(public.containsKey('documents'), isFalse);
    expect(raw.contains('baseSnapshot'), isFalse);
    expect(raw.contains(_ownerAvatar), isFalse);
    expect(raw.contains('Сохранённая база'), isFalse);
  });
}

const _ownerAvatar =
    'accounts/owner/media/0123456789abcdef0123456789abcdef.jpg';
const _foreignAvatar =
    'accounts/other/media/0123456789abcdef0123456789abcdef.jpg';

PortfolioContent _base({
  String name = 'Сохранённая база',
  String avatarPath = _ownerAvatar,
}) => PortfolioContent(
  profile: PortfolioProfile(
    name: name,
    headline: 'Разработчик',
    locationText: 'Алматы, Казахстан',
    avatarPath: avatarPath,
  ),
  skills: const [Skill(id: 'skill', name: 'Dart')],
  experience: const [
    Experience(
      id: 'experience',
      role: 'Developer',
      organization: 'Team',
      period: '2025–2026',
      description: 'Сохранённый опыт',
    ),
  ],
  education: const [
    Education(
      id: 'education',
      institution: 'AlmaU',
      qualification: 'Software Engineering',
      period: '2023–2027',
      description: '',
    ),
  ],
  links: const [
    SocialLink(id: 'link', label: 'Website', url: 'https://example.com'),
  ],
);

PortfolioContent _workspace(DateTime now, {String avatarPath = _ownerAvatar}) =>
    PortfolioContent(
      profile: const PortfolioProfile(name: 'Текущая общая база'),
      documents: [
        PortfolioDocument(
          id: 'resume',
          title: 'Резюме',
          kind: PortfolioDocumentKind.resume,
          createdAt: now,
          updatedAt: now,
          content: _base(avatarPath: avatarPath).copyWith(
            profile: PortfolioProfile(
              name: 'Своё имя документа',
              avatarPath: avatarPath,
            ),
          ),
          baseSnapshot: _base(avatarPath: avatarPath),
        ),
      ],
    );

Map<String, Object?> _legacyContent(PortfolioContent workspace) {
  final encoded = encodePortfolioContent(workspace);
  for (final document in encoded['documents'] as List) {
    (document as Map).remove('baseSnapshot');
  }
  return encoded;
}

String _legacyEnvelope(PortfolioContent workspace, DateTime now) => jsonEncode({
  'schemaVersion': 5,
  'notes': '  Legacy exact notes\n',
  'revision': 3,
  'updatedAt': now.toIso8601String(),
  'pendingSync': true,
  'content': _legacyContent(workspace),
});

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
      throw const FileSystemException('Injected backup failure');
    }
    await delegate.put(key, value);
  }

  @override
  Future<void> delete(dynamic key) => delegate.delete(key);
  @override
  Future<void> flush() async {
    if (rejectFlush) throw const FileSystemException('Injected flush failure');
    await delegate.flush();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
