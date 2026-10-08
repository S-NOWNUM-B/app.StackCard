import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart';
import 'package:app_stackcard/features/portfolio_draft/data/local_draft_accounts.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_document_base_review.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_github_sync.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_sync.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_validation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'support/legacy_portfolio_content.dart';

void main() {
  final now = DateTime.utc(2026, 10, 8);
  late Directory directory;
  late Box<dynamic> box;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stackcard-privacy-');
    box = await Hive.openBox<dynamic>('privacy', path: directory.path);
  });
  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });
  Future<void> reopen() async {
    await box.close();
    box = await Hive.openBox<dynamic>('privacy', path: directory.path);
  }

  test('shared schema6 fixture matches the Dart cloud writer without dropping fields', () {
    final fixture = jsonDecode(
      File('../../fixtures/workspace/schema6.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final timestamp = DateTime.parse(fixture['updatedAt'] as String);
    final draft = decodeCloudPortfolioDraft({
      ...fixture,
      'updatedAt': Timestamp.fromDate(timestamp),
    }, ownerUid: 'owner');
    expect(draft.content, _workspace(now));
    final encoded = encodeCloudPortfolioDraft(draft);
    encoded['updatedAt'] = timestamp.toIso8601String();
    expect(encoded, fixture);
  });

  test('document presentation resolves independently and clearing inherits latest Library', () {
    final workspace = _workspace(now);
    final first = workspace.documents.first;
    final second = workspace.documents.last;
    final resolved = resolveDocumentContent(workspace, first).projects.single;
    expect(resolved.title, 'Document title');
    expect(resolved.description, isEmpty);
    expect(resolved.contribution, 'Document contribution');
    expect(resolved.featured, isTrue);
    expect(workspace.projects.single.title, 'Library title');
    expect(workspace.projects.single.description, 'Library description');
    expect(
      resolveDocumentContent(workspace, second).projects.single.contribution,
      'Library contribution',
    );
    final latest = workspace.copyWith(
      projects: [workspace.projects.single.copyWith(title: 'Latest Library')],
    );
    expect(
      resolveDocumentContent(latest, first).projects.single.title,
      'Document title',
    );
    expect(
      resolveDocumentContent(latest, second).projects.single.title,
      'Latest Library',
    );
    final inherited = first.copyWith(
      projects: [
        first.projects.single.copyWith(
          clearTitleOverride: true,
          clearDescriptionOverride: true,
          clearContributionOverride: true,
        ),
      ],
    );
    expect(
      resolveDocumentContent(latest, inherited).projects.single,
      latest.projects.single.copyWith(featured: true),
    );
    expect(first.projects.single.copyWith(), first.projects.single);
    expect(
      first.projects.single.copyWith(descriptionOverride: 'Changed'),
      isNot(first.projects.single),
    );
  });

  test('project contribution survives source-aware user edits without creating a GitHub override', () {
    final project = addGitHubProject(
      PortfolioContent(),
      GitHubProjectSource(
        repositoryId: 42,
        name: 'Library',
        fullName: 'owner/Library',
        htmlUrl: 'https://github.com/owner/Library',
        description: 'Source description',
        language: 'Dart',
        stars: 1,
        forks: 0,
        isFork: false,
        archived: false,
        updatedAt: now,
      ),
    ).projects.single;
    final edited = project.withUserEdits(
      project.copyWith(contribution: 'My independent contribution'),
    );
    expect(edited.contribution, 'My independent contribution');
    expect(edited.title, project.title);
    expect(edited.githubMetadata, project.githubMetadata);
    expect(edited.githubMetadata!.overrideFields, isEmpty);
    expect(edited, isNot(project));
  });

  test('privacy defaults do not authorize contact or location publication', () {
    const contact = SocialLink(
      id: 'email',
      label: 'Email',
      url: 'mailto:owner@example.com',
      kind: SocialLinkKind.email,
    );
    expect(contact.publishAllowed, isFalse);
    expect(contact.visible, isTrue);
    expect(const PortfolioProfile().publishLocation, isFalse);
    expect(contact.copyWith(publishAllowed: true), isNot(contact));
    expect(contact.copyWith(visible: false), isNot(contact));
    expect(contact.copyWith(), contact);
  });

  test('contact URL validation retains legacy links and rejects unsafe typed values', () {
    final valid = <SocialLinkKind, String>{
      SocialLinkKind.email: 'mailto:first.last+work@example.com',
      SocialLinkKind.phone: 'tel:+77011234567',
      SocialLinkKind.telegram: 'https://t.me/snownumb',
      SocialLinkKind.website: 'http://legacy.example.com/?section=about#bio',
    };
    for (final entry in valid.entries) {
      expect(validatePortfolioContactUrl(entry.value, entry.key), isNull);
    }
    final invalid = <SocialLinkKind, List<String>>{
      SocialLinkKind.email: [
        'owner@example.com',
        'mailto:owner@example.com?bcc=private@example.com',
        'mailto:owner@example.com#fragment',
        'mailto:owner%0d%0aBcc@example.com',
        'mailto://owner@example.com',
        'mailto:owner@-example.com',
        'mailto:owner@example.com\n',
      ],
      SocialLinkKind.phone: [
        'tel:77011234567',
        'tel:+1',
        'tel:+1234567890123456',
        'tel:+77011234567;ext=123',
        'tel:+77011234567?call=1',
        'tel:+77011234567\u0000',
      ],
      SocialLinkKind.telegram: [
        'http://t.me/snownumb',
        'https://t.me:443/snownumb',
        'https://t.me.evil.example/snownumb',
        'https://owner@t.me/snownumb',
        'https://t.me/snownumb?start=secret',
        'https://t.me/snownumb#fragment',
        'https://t.me/+invite',
      ],
      SocialLinkKind.other: [
        'javascript:alert(1)',
        'https://site.example/\u0000',
      ],
    };
    for (final entry in invalid.entries) {
      for (final value in entry.value) {
        expect(
          validatePortfolioContactUrl(value, entry.key),
          isNotNull,
          reason: '${entry.key}: $value',
        );
      }
    }
  });

  test('avatar and project URLs reject controls before a private Save', () {
    final workspace = _workspace(now);
    for (final url in [
      'https:site.example',
      'https://site.example/\u0000unsafe',
      'https://site.example/\u001funsafe',
      'https://site.example/\u007funsafe',
    ]) {
      expect(validatePortfolioUrl(url), PortfolioValidationCode.invalidUrl);
      for (final invalid in [
        workspace.copyWith(profile: workspace.profile.copyWith(avatarUrl: url)),
        workspace.copyWith(
          projects: [workspace.projects.single.copyWith(liveUrl: url)],
        ),
      ]) {
        expect(
          validatePortfolioContent(invalid),
          contains(PortfolioValidationCode.invalidUrl),
        );
        expect(
          () => decodePortfolioContent(encodePortfolioContent(invalid)),
          throwsFormatException,
        );
      }
    }
    expect(
      validatePortfolioUrl('https://site.example/?q=allowed#section'),
      isNull,
    );
  });

  test('presentation limits reject invalid overrides and contribution', () {
    final workspace = _workspace(now);
    for (final attachment in [
      const PortfolioProjectAttachment(projectId: 'project', titleOverride: ''),
      PortfolioProjectAttachment(
        projectId: 'project',
        titleOverride: 'a' * 121,
      ),
      PortfolioProjectAttachment(
        projectId: 'project',
        descriptionOverride: 'a' * 4001,
      ),
      PortfolioProjectAttachment(
        projectId: 'project',
        contributionOverride: 'a' * 4001,
      ),
    ]) {
      final invalid = workspace.copyWith(
        documents: [
          workspace.documents.first.copyWith(projects: [attachment]),
        ],
      );
      expect(validatePortfolioContent(invalid), isNotEmpty);
      expect(
        () => decodePortfolioContent(encodePortfolioContent(invalid)),
        throwsFormatException,
      );
    }
    expect(
      validatePortfolioContent(
        workspace.copyWith(
          projects: [
            workspace.projects.single.copyWith(contribution: 'a' * 4001),
          ],
        ),
      ),
      contains(PortfolioValidationCode.tooLong),
    );
    expect(validatePortfolioContent(workspace), isEmpty);
  });

  test('base review retains document contact selection and requires explicit location consent review', () {
    final workspace = _workspace(now);
    final document = workspace.documents.first;
    final base = developerProfileData(workspace).copyWith(
      profile: workspace.profile.copyWith(publishLocation: false),
      links: [workspace.links.single.copyWith(label: 'New base label')],
    );
    final review = PortfolioDocumentBaseReview(document: document, base: base);
    final applied = review.apply({'links:email', 'publishLocation:'});
    expect(applied.content.links.single.label, 'New base label');
    expect(applied.content.links.single.visible, isFalse);
    expect(applied.content.profile.publishLocation, isFalse);
    expect(applied.projects, document.projects);
    expect(document.content.profile.publishLocation, isTrue);
    expect(document.content.links.single.label, 'Work email');
    final notSelected = review.apply({});
    expect(notSelected.content, document.content);
    expect(notSelected.baseSnapshot, base);
  });

  test('codec recursively preserves snapshots, eligibility and independent presentation', () {
    final workspace = _workspace(now);
    final encoded = _json(workspace);
    expect(decodePortfolioContent(encoded), workspace);
    expect(decodePortfolioContent(encoded).hashCode, workspace.hashCode);
    final document = (encoded['documents'] as List).first as Map;
    final attachment = (document['projects'] as List).single as Map;
    expect(attachment.keys.toSet(), {
      'projectId',
      'visible',
      'featured',
      'titleOverride',
      'descriptionOverride',
      'contributionOverride',
    });
    expect((document['content'] as Map)['links'][0]['visible'], isFalse);
    expect((encoded['links'] as List).single['publishAllowed'], isTrue);
    expect(
      () => decodePortfolioContent(encoded, allowPresentationPrivacy: false),
      throwsFormatException,
    );
  });

  test(
    'malformed privacy and presentation types cannot be silently dropped',
    () {
      final mutations = <void Function(Map<String, dynamic>)>[
        (json) => (json['profile'] as Map)['publishLocation'] = 'true',
        (json) => (json['links'] as List).single['publishAllowed'] = 1,
        (json) => (json['links'] as List).single['visible'] = null,
        (json) => (json['projects'] as List).single['contribution'] = false,
        (json) => _attachment(json)['titleOverride'] = 42,
        (json) => _attachment(json)['contributionOverride'] = [],
        (json) => _documentContent(json)['links'][0]['publishAllowed'] = 'yes',
        (json) =>
            (json['documents'] as List)
                    .first['baseSnapshot']['profile']['publishLocation'] =
                null,
      ];
      for (final mutate in mutations) {
        final raw = _json(_workspace(now));
        mutate(raw);
        expect(() => decodePortfolioContent(raw), throwsFormatException);
      }
    },
  );

  test(
    'Hive7 snapshots, outbox and revision ACK survive actual reopen',
    () async {
      final workspace = _workspace(now);
      final saved = await HivePortfolioDraftRepository(
        box,
        clock: () => now,
      ).save(workspace, expectedRevision: 0, notes: 'Private notes');
      await HivePortfolioSyncMetadataStore(box, ownerUid: 'owner').write(
        PortfolioSyncRecord(
          mutationId: 'privacy-op',
          pending: true,
          draft: saved,
        ),
      );
      await reopen();
      final repository = HivePortfolioDraftRepository(box);
      expect((await repository.read())!.content, workspace);
      expect(
        (await HivePortfolioSyncMetadataStore(
          box,
          ownerUid: 'owner',
        ).read())!.draft.content,
        workspace,
      );
      await repository.acknowledgeRevision(1);
      await reopen();
      expect(
        (await HivePortfolioDraftRepository(box).read())!.content,
        workspace,
      );
      expect(
        (await HivePortfolioDraftRepository(box).read())!.pendingSync,
        isFalse,
      );
    },
  );

  for (final operation in ['save', 'notes', 'ack']) {
    test(
      'legacy Hive6 $operation upgrade preserves raw backup and privacy defaults',
      () async {
        final legacyContent = _legacy(_workspace(now));
        final raw = jsonEncode(_envelope(legacyContent, now));
        await box.put('draft', raw);
        final repository = HivePortfolioDraftRepository(box, clock: () => now);
        final read = (await repository.read())!;
        expect(read.content!.profile.publishLocation, isFalse);
        expect(read.content!.links.single.publishAllowed, isFalse);
        expect(
          read.content!.documents.first.content.links.single.visible,
          isTrue,
        );
        expect(
          read.content!.documents.first.projects.single.titleOverride,
          isNull,
        );
        expect(box.get('draft'), raw);
        expect(box.keys, ['draft']);
        if (operation == 'save') {
          await repository.save(
            _workspace(now),
            expectedRevision: 3,
            notes: read.notes,
          );
        } else if (operation == 'notes') {
          await repository.saveNotes('Changed notes');
        } else {
          await repository.acknowledgeRevision(3);
        }
        await reopen();
        expect(box.get('draft.v6.backup'), raw);
        expect(
          (jsonDecode(box.get('draft') as String) as Map)['schemaVersion'],
          7,
        );
        final restored = (await HivePortfolioDraftRepository(box).read())!;
        expect(
          restored.content,
          operation == 'save' ? _workspace(now) : read.content,
        );
      },
    );
  }

  test('Hive6 cannot hide new keys in nested snapshots; corrupted bytes survive attempted overwrite', () async {
    final mutations = <void Function(Map<String, dynamic>)>[
      (json) => (json['profile'] as Map)['publishLocation'] = false,
      (json) => _documentContent(json)['links'][0]['visible'] = true,
      (json) => _attachment(json)['titleOverride'] = null,
      (json) =>
          (json['documents'] as List)
                  .first['baseSnapshot']['links'][0]['publishAllowed'] =
              false,
    ];
    for (final mutate in mutations) {
      final legacy = _legacy(_workspace(now));
      mutate(legacy);
      final raw = jsonEncode(_envelope(legacy, now));
      await box.put('draft', raw);
      final repository = HivePortfolioDraftRepository(box);
      await expectLater(repository.read(), throwsA(_corrupted));
      await expectLater(repository.saveNotes('Overwrite'), throwsA(_corrupted));
      expect(box.get('draft'), raw);
    }
  });

  test('guest transfer carries Hive6 raw backup, private snapshot and UID isolation', () async {
    final raw = jsonEncode(_envelope(_legacy(_workspace(now)), now));
    await box.put('draft', raw);
    await LocalDraftAccounts(box).guestRepository
        .save(_workspace(now), expectedRevision: 3, notes: 'Guest notes');
    await reopen();
    await LocalDraftAccounts(box).transferGuestToUser('owner');
    await reopen();
    final key =
        'draft.user.${base64Url.encode(utf8.encode('owner')).replaceAll('=', '')}';
    expect(box.get('$key.v6.backup'), raw);
    expect(box.containsKey('draft.v6.backup'), isFalse);
    expect(
      (await LocalDraftAccounts(
        box,
      ).repositoryForUser('owner').read())!.content,
      _workspace(now),
    );
    expect(
      await LocalDraftAccounts(box).repositoryForUser('other').read(),
      isNull,
    );
  });

  test('cloud6 roundtrips new fields, cloud5 defaults legacy data and rejects downgrade keys', () {
    final workspace = _workspace(now);
    final encoded = encodeCloudPortfolioDraft(
      CloudPortfolioDraft(
        ownerUid: 'owner',
        mutationId: 'privacy-cloud',
        localRevision: 1,
        notes: 'Private notes',
        content: workspace,
      ),
    );
    expect(encoded['schemaVersion'], 6);
    final stored = {...encoded, 'updatedAt': Timestamp.fromDate(now)};
    expect(
      decodeCloudPortfolioDraft(stored, ownerUid: 'owner').content,
      workspace,
    );
    final legacy = {
      ...stored,
      'schemaVersion': 5,
      'content': _legacy(workspace),
    };
    final old = decodeCloudPortfolioDraft(legacy, ownerUid: 'owner').content!;
    expect(old.profile.publishLocation, isFalse);
    expect(old.projects.single.contribution, isEmpty);
    expect(old.links.single.publishAllowed, isFalse);
    expect(old.documents.first.baseSnapshot!.links.single.visible, isTrue);
    for (final version in [1, 2, 3, 4, 5, 7]) {
      expect(
        () => decodeCloudPortfolioDraft({
          ...stored,
          'schemaVersion': version,
        }, ownerUid: 'owner'),
        throwsA(_invalidCloud),
      );
    }
  });
}

PortfolioContent _workspace(DateTime now) {
  const link = SocialLink(
    id: 'email',
    label: 'Work email',
    url: 'mailto:owner@example.com',
    kind: SocialLinkKind.email,
    publishAllowed: true,
  );
  final base = PortfolioContent(
    profile: const PortfolioProfile(
      name: 'Owner',
      locationText: 'Almaty',
      publishLocation: true,
    ),
    links: const [link],
    projects: [
      PortfolioProject(
        id: 'project',
        title: 'Library title',
        description: 'Library description',
        contribution: 'Library contribution',
        technologies: ['Dart'],
      ),
    ],
  );
  final snapshot = seedDocumentContent(base);
  return base.copyWith(
    documents: [
      PortfolioDocument(
        id: 'first',
        title: 'First',
        kind: PortfolioDocumentKind.resume,
        createdAt: now,
        updatedAt: now,
        content: snapshot.copyWith(links: [link.copyWith(visible: false)]),
        baseSnapshot: developerProfileData(base),
        projects: const [
          PortfolioProjectAttachment(
            projectId: 'project',
            featured: true,
            titleOverride: 'Document title',
            descriptionOverride: '',
            contributionOverride: 'Document contribution',
          ),
        ],
      ),
      PortfolioDocument(
        id: 'second',
        title: 'Second',
        kind: PortfolioDocumentKind.portfolio,
        createdAt: now,
        updatedAt: now,
        content: snapshot,
        projects: const [PortfolioProjectAttachment(projectId: 'project')],
      ),
    ],
  );
}

Map<String, dynamic> _json(PortfolioContent content) =>
    jsonDecode(jsonEncode(encodePortfolioContent(content)))
        as Map<String, dynamic>;

Map<String, dynamic> _legacy(PortfolioContent content) {
  final encoded = _json(content);
  removePresentationPrivacyFields(encoded);
  // Legacy schemas знали только web links, поэтому fixture сохраняет URL тип.
  void oldLinks(Map<String, dynamic> value) {
    for (final link in value['links'] as List) {
      link['kind'] = 'other';
      link['url'] = 'https://example.com';
    }
  }

  oldLinks(encoded);
  for (final document in encoded['documents'] as List) {
    oldLinks(document['content'] as Map<String, dynamic>);
    if (document['baseSnapshot'] case final Map<String, dynamic> base) {
      oldLinks(base);
    }
  }
  return encoded;
}

Map<String, Object?> _envelope(Map<String, dynamic> content, DateTime now) => {
  'schemaVersion': 6,
  'notes': '  Exact notes\n',
  'revision': 3,
  'updatedAt': now.toIso8601String(),
  'pendingSync': true,
  'content': content,
};
Map<String, dynamic> _attachment(Map<String, dynamic> json) =>
    ((json['documents'] as List).first['projects'] as List).single
        as Map<String, dynamic>;
Map<String, dynamic> _documentContent(Map<String, dynamic> json) =>
    (json['documents'] as List).first['content'] as Map<String, dynamic>;
final _corrupted = isA<PortfolioDraftFailure>().having(
  (error) => error.kind,
  'kind',
  PortfolioDraftFailureKind.corrupted,
);
final _invalidCloud = isA<PortfolioSyncFailure>().having(
  (error) => error.kind,
  'kind',
  PortfolioSyncFailureKind.invalidData,
);
