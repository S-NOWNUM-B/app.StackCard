import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  final now = DateTime.utc(2026, 10, 3, 18);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stackcard-builder-');
    box = await Hive.openBox<dynamic>('draft', path: directory.path);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('V1 read preserves exact notes and metadata without writing or seeding content', () async {
    final raw = jsonEncode(_legacy(now));
    await box.put('draft', raw);
    final repository = HivePortfolioDraftRepository(
      box,
      clock: () => now.add(const Duration(days: 300)),
    );
    final draft = (await repository.read())!;
    expect(draft.content, isNull);
    expect(draft.notes, '  Private notes\nKeep whitespace  ');
    expect(draft.revision, 4);
    expect(draft.updatedAt, now);
    expect(draft.pendingSync, isFalse);
    expect(box.get('draft'), raw);
    expect(box.keys.toList(), ['draft']);
  });

  test('Explicit full save migrates V1 once, keeps raw backup and private notes separate', () async {
    final raw = jsonEncode(_legacy(now));
    await box.put('draft', raw);
    final repository = HivePortfolioDraftRepository(
      box,
      clock: () => now.add(const Duration(minutes: 1)),
    );
    final content = _content();
    final saved = await repository.save(
      content,
      expectedRevision: 4,
      notes: _legacy(now)['notes'] as String,
    );
    expect(saved.revision, 5);
    expect(saved.content, content);
    expect(saved.updatedAt, now.add(const Duration(minutes: 1)));
    expect(saved.pendingSync, isTrue);
    expect(box.get(HivePortfolioDraftRepository.legacyBackupKey), raw);
    final envelope =
        jsonDecode(box.get('draft') as String) as Map<String, dynamic>;
    expect(
      envelope['schemaVersion'],
      HivePortfolioDraftRepository.schemaVersion,
    );
    expect(
      (envelope['content'] as Map<String, dynamic>).containsKey('notes'),
      isFalse,
    );
    await repository.save(
      content.copyWith(resumeText: 'Changed\nResume'),
      expectedRevision: 5,
      notes: saved.notes,
    );
    expect(box.get(HivePortfolioDraftRepository.legacyBackupKey), raw);
    expect((await repository.read())!.revision, 6);
  });

  test(
    'Notes-only first write migrates without inventing Builder content',
    () async {
      final raw = jsonEncode(_legacy(now));
      await box.put('draft', raw);
      final repository = HivePortfolioDraftRepository(box, clock: () => now);
      final saved = await repository.saveNotes('Changed private notes');
      expect(saved.content, isNull);
      expect(saved.revision, 5);
      expect(box.get(HivePortfolioDraftRepository.legacyBackupKey), raw);
      expect(
        (jsonDecode(box.get('draft') as String) as Map)['content'],
        isNull,
      );
    },
  );

  test('All content fields, ordered hidden blocks and plain resume survive real reopen', () async {
    final repository = HivePortfolioDraftRepository(box, clock: () => now);
    final content = _content();
    await repository.save(content, expectedRevision: 0, notes: 'Private');
    await box.close();
    box = await Hive.openBox<dynamic>('draft', path: directory.path);
    final reopened = HivePortfolioDraftRepository(
      box,
      clock: () => now.add(const Duration(days: 400)),
    );
    final restored = (await reopened.read())!;
    expect(restored.content, content);
    expect(restored.content.hashCode, content.hashCode);
    expect(restored.notes, 'Private');
    expect(restored.content!.resumeText, 'First line\n\nSecond line');
    expect(restored.content!.blocks.first.kind, PortfolioBlockKind.location);
    expect(restored.content!.blocks.first.visible, isFalse);
    expect(restored.content!.theme, PortfolioTheme.light);
    expect(restored.revision, 1);
    expect(restored.updatedAt, now);
    expect(restored.pendingSync, isTrue);
  });

  test(
    'Legacy notes update patches only notes after full content was saved',
    () async {
      final repository = HivePortfolioDraftRepository(box, clock: () => now);
      await repository.save(_content(), expectedRevision: 0, notes: 'Original');
      final result = await repository.saveNotes('Only notes changed');
      expect(result.content, _content());
      expect(result.notes, 'Only notes changed');
      expect(result.revision, 2);
      expect((await repository.read())!.content, _content());
    },
  );

  test('Stale expected revision rejects replacement and preserves latest durable content', () async {
    final repository = HivePortfolioDraftRepository(box, clock: () => now);
    final saved = await repository.save(
      _content(),
      expectedRevision: 0,
      notes: 'First',
    );
    final raw = box.get('draft');
    await expectLater(
      repository.save(
        _content().copyWith(resumeText: 'Stale'),
        expectedRevision: 0,
        notes: 'Wrong notes',
      ),
      throwsA(_failure(PortfolioDraftFailureKind.conflict)),
    );
    expect(box.get('draft'), raw);
    expect((await repository.read())!.notes, saved.notes);
    expect((await repository.read())!.revision, 1);
  });

  test(
    'Concurrent full saves check revision inside the serialized operation',
    () async {
      final repository = HivePortfolioDraftRepository(box, clock: () => now);
      final first = repository.save(
        _content(),
        expectedRevision: 0,
        notes: 'First',
      );
      final second = expectLater(
        repository.save(
          _content().copyWith(resumeText: 'Second'),
          expectedRevision: 0,
          notes: 'Second',
        ),
        throwsA(_failure(PortfolioDraftFailureKind.conflict)),
      );
      await first;
      await second;
      expect((await repository.read())!.notes, 'First');
      expect((await repository.read())!.revision, 1);
      await repository.save(
        _content().copyWith(resumeText: 'Explicit retry'),
        expectedRevision: 1,
        notes: 'Updated',
      );
      expect((await repository.read())!.revision, 2);
    },
  );

  test('Invalid content never creates an entry or migration backup', () async {
    final repository = HivePortfolioDraftRepository(box);
    final invalid = PortfolioContent(
      skills: [const Skill(id: 's', name: ' ')],
    );
    await expectLater(
      repository.save(invalid, expectedRevision: 0, notes: 'Private'),
      throwsA(_failure(PortfolioDraftFailureKind.invalidContent)),
    );
    expect(box.isEmpty, isTrue);
    final raw = jsonEncode(_legacy(now));
    await box.put('draft', raw);
    await expectLater(
      repository.save(invalid, expectedRevision: 4, notes: 'Changed'),
      throwsA(_failure(PortfolioDraftFailureKind.invalidContent)),
    );
    expect(box.get('draft'), raw);
    expect(
      box.containsKey(HivePortfolioDraftRepository.legacyBackupKey),
      isFalse,
    );
  });

  test(
    'Backup write failure leaves V1 exact and does not replace main entry',
    () async {
      final raw = jsonEncode(_legacy(now));
      await box.put('draft', raw);
      final failing = _WriteGateBox(box)
        ..rejectKey = HivePortfolioDraftRepository.legacyBackupKey;
      final repository = HivePortfolioDraftRepository(
        failing,
        clock: () => now,
      );
      await expectLater(
        repository.save(_content(), expectedRevision: 4, notes: 'Changed'),
        throwsA(_failure(PortfolioDraftFailureKind.unavailable)),
      );
      expect(box.get('draft'), raw);
      expect(
        box.containsKey(HivePortfolioDraftRepository.legacyBackupKey),
        isFalse,
      );
      expect(failing.writes, [HivePortfolioDraftRepository.legacyBackupKey]);
      failing.rejectKey = null;
      expect(
        (await repository.save(
          _content(),
          expectedRevision: 4,
          notes: 'Retry',
        )).revision,
        5,
      );
    },
  );

  test('Main write failure after backup retains V1 and a retry uses the same revision', () async {
    final raw = jsonEncode(_legacy(now));
    await box.put('draft', raw);
    final failing = _WriteGateBox(box)..rejectKey = 'draft';
    final repository = HivePortfolioDraftRepository(failing, clock: () => now);
    await expectLater(
      repository.save(_content(), expectedRevision: 4, notes: 'Changed'),
      throwsA(_failure(PortfolioDraftFailureKind.unavailable)),
    );
    expect(box.get('draft'), raw);
    expect(box.get(HivePortfolioDraftRepository.legacyBackupKey), raw);
    expect((await repository.read())!.revision, 4);
    failing.rejectKey = null;
    expect(
      (await repository.save(
        _content(),
        expectedRevision: 4,
        notes: 'Retry',
      )).revision,
      5,
    );
  });

  test(
    'Failed V2 save keeps durable content and private notes unchanged',
    () async {
      final failing = _WriteGateBox(box);
      final repository = HivePortfolioDraftRepository(
        failing,
        clock: () => now,
      );
      await repository.save(_content(), expectedRevision: 0, notes: 'Durable');
      final raw = box.get('draft');
      failing.rejectKey = 'draft';
      await expectLater(
        repository.save(
          _content().copyWith(resumeText: 'Unsaved'),
          expectedRevision: 1,
          notes: 'Unwritten',
        ),
        throwsA(_failure(PortfolioDraftFailureKind.unavailable)),
      );
      expect(box.get('draft'), raw);
      expect((await repository.read())!.notes, 'Durable');
      expect((await repository.read())!.content, _content());
    },
  );

  test('Existing migration backup is never silently overwritten', () async {
    final raw = jsonEncode(_legacy(now));
    await box.put('draft', raw);
    await box.put(
      HivePortfolioDraftRepository.legacyBackupKey,
      'Another original',
    );
    final repository = HivePortfolioDraftRepository(box);
    await expectLater(
      repository.save(_content(), expectedRevision: 4, notes: 'Changed'),
      throwsA(_failure(PortfolioDraftFailureKind.corrupted)),
    );
    expect(box.get('draft'), raw);
    expect(
      box.get(HivePortfolioDraftRepository.legacyBackupKey),
      'Another original',
    );
  });

  test(
    'Unknown schema prevents both full save and notes-only overwrite',
    () async {
      final raw = jsonEncode(_legacy(now)..['schemaVersion'] = 99);
      await box.put('draft', raw);
      final repository = HivePortfolioDraftRepository(box);
      await expectLater(
        repository.read(),
        throwsA(_failure(PortfolioDraftFailureKind.unsupportedVersion)),
      );
      await expectLater(
        repository.save(_content(), expectedRevision: 4, notes: 'Changed'),
        throwsA(_failure(PortfolioDraftFailureKind.unsupportedVersion)),
      );
      await expectLater(
        repository.saveNotes('Changed'),
        throwsA(_failure(PortfolioDraftFailureKind.unsupportedVersion)),
      );
      expect(box.get('draft'), raw);
      expect(box.keys.toList(), ['draft']);
    },
  );

  test(
    'Malformed V2 content is preserved and cannot be patched away',
    () async {
      final repository = HivePortfolioDraftRepository(box, clock: () => now);
      await repository.save(_content(), expectedRevision: 0, notes: 'Private');
      final original = box.get('draft') as String;
      final mutations = <void Function(Map<String, dynamic>)>[
        (json) => json.remove('content'),
        (json) => json['content'] = [],
        (json) => (json['content'] as Map)['profile'] = 42,
        (json) => ((json['content'] as Map)['profile'] as Map).remove('name'),
        (json) => ((json['content'] as Map)['profile'] as Map)['username'] =
            'INVALID',
        (json) => (json['content'] as Map)['skills'] = 'not a list',
        (json) =>
            (((json['content'] as Map)['skills'] as List).first as Map)['id'] =
                12,
        (json) =>
            (((json['content'] as Map)['projects'] as List).first
                    as Map)['featured'] =
                1,
        (json) =>
            (((json['content'] as Map)['projects'] as List).first
                as Map)['technologies'] = [
              42,
            ],
        (json) =>
            (((json['content'] as Map)['links'] as List).first as Map)['kind'] =
                'unknown',
        (json) => (json['content'] as Map)['theme'] = 'unknown',
        (json) => (json['content'] as Map)['blocks'] = [],
        (json) => (json['content'] as Map)['resumeText'] = 'x' * 20001,
      ];
      for (final mutate in mutations) {
        final json = jsonDecode(original) as Map<String, dynamic>;
        mutate(json);
        final corrupted = jsonEncode(json);
        await box.put('draft', corrupted);
        await expectLater(
          repository.read(),
          throwsA(_failure(PortfolioDraftFailureKind.corrupted)),
        );
        await expectLater(
          repository.saveNotes('Overwrite'),
          throwsA(_failure(PortfolioDraftFailureKind.corrupted)),
        );
        await expectLater(
          repository.save(_content(), expectedRevision: 1, notes: 'Overwrite'),
          throwsA(_failure(PortfolioDraftFailureKind.corrupted)),
        );
        expect(box.get('draft'), corrupted);
      }
    },
  );

  test('Memory repository has the same revision, validation and notes patch contract', () async {
    final repository = MemoryPortfolioDraftRepository(clock: () => now);
    expect(await repository.read(), isNull);
    final saved = await repository.save(
      _content(),
      expectedRevision: 0,
      notes: 'Private',
    );
    expect(saved.updatedAt, now);
    expect(saved.pendingSync, isTrue);
    expect((await repository.saveNotes('Patched')).content, _content());
    await expectLater(
      repository.save(_content(), expectedRevision: 1, notes: 'Stale'),
      throwsA(_failure(PortfolioDraftFailureKind.conflict)),
    );
    await expectLater(
      repository.save(
        PortfolioContent(blocks: []),
        expectedRevision: 2,
        notes: 'Invalid',
      ),
      throwsA(_failure(PortfolioDraftFailureKind.invalidContent)),
    );
    expect((await repository.read())!.notes, 'Patched');
    expect((await repository.read())!.revision, 2);
  });
}

Map<String, Object?> _legacy(DateTime now) => {
  'schemaVersion': 1,
  'notes': '  Private notes\nKeep whitespace  ',
  'revision': 4,
  'updatedAt': now.toIso8601String(),
  'pendingSync': false,
};

PortfolioContent _content() => PortfolioContent(
  profile: const PortfolioProfile(
    name: 'Sam Lee',
    username: 'sam-lee',
    headline: 'Engineer',
    bio: 'Builds apps',
    locationText: 'Almaty',
    avatarUrl: 'https://example.com/avatar.png',
  ),
  skills: [const Skill(id: 's', name: 'Dart')],
  projects: [
    PortfolioProject(
      id: 'p',
      title: 'My project',
      description: 'Local description',
      technologies: ['Dart', 'Flutter'],
      repositoryUrl: 'https://github.com/example/project',
      liveUrl: 'https://example.com',
      featured: true,
      visible: false,
    ),
  ],
  experience: [
    const Experience(
      id: 'e',
      role: 'Engineer',
      organization: 'Studio',
      period: '2024–2026',
      description: 'Built apps',
    ),
  ],
  education: [
    const Education(
      id: 'ed',
      institution: 'University',
      qualification: 'Software engineering',
      period: '2023–2027',
      description: 'Studies',
    ),
  ],
  links: [
    const SocialLink(
      id: 'l',
      label: 'GitHub',
      url: 'https://github.com/example',
      kind: SocialLinkKind.github,
    ),
  ],
  resumeText: 'First line\n\nSecond line',
  blocks: PortfolioBlockKind.values.reversed
      .map(
        (kind) => PortfolioBlock(
          kind: kind,
          visible: kind != PortfolioBlockKind.location,
        ),
      )
      .toList(),
  theme: PortfolioTheme.light,
);

Matcher _failure(PortfolioDraftFailureKind kind) => isA<PortfolioDraftFailure>()
    .having((failure) => failure.kind, 'kind', kind);

final class _WriteGateBox implements Box<dynamic> {
  _WriteGateBox(this.box);
  final Box<dynamic> box;
  String? rejectKey;
  final writes = <dynamic>[];
  @override
  bool containsKey(dynamic key) => box.containsKey(key);
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      box.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, dynamic value) async {
    writes.add(key);
    if (key == rejectKey) {
      throw const FileSystemException('Storage rejected write');
    }
    await box.put(key, value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
