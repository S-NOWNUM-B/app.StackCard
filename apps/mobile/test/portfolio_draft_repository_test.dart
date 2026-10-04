import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  final now = DateTime.utc(2026, 10, 3, 12);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stackcard-draft-test-');
    box = await Hive.openBox<dynamic>('draft', path: directory.path);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'Empty Hive box is editable and saves one durable versioned envelope',
    () async {
      final repository = HivePortfolioDraftRepository(box, clock: () => now);
      expect(await repository.read(), isNull);
      final saved = await repository.saveNotes('  Мои планы\nFlutter  ');
      expect(saved.notes, '  Мои планы\nFlutter  ');
      expect(saved.revision, 1);
      expect(saved.updatedAt, now);
      expect(saved.pendingSync, isTrue);
      expect(box.keys.toList(), ['draft']);
      expect(jsonDecode(box.get('draft') as String), {
        'schemaVersion': HivePortfolioDraftRepository.schemaVersion,
        'notes': saved.notes,
        'revision': 1,
        'updatedAt': now.toIso8601String(),
        'pendingSync': true,
        'content': null,
      });
    },
  );

  test(
    'Close and reopen preserve pending notes without network or TTL',
    () async {
      final repository = HivePortfolioDraftRepository(box, clock: () => now);
      await repository.saveNotes('Remember this draft');
      await box.close();
      box = await Hive.openBox<dynamic>('draft', path: directory.path);
      final restarted = HivePortfolioDraftRepository(
        box,
        clock: () => now.add(const Duration(days: 400)),
      );
      final saved = (await restarted.read())!;
      expect(saved.notes, 'Remember this draft');
      expect(saved.revision, 1);
      expect(saved.updatedAt, now);
      expect(saved.pendingSync, isTrue);
      final next = await restarted.saveNotes('New notes');
      expect(next.revision, 2);
      expect(next.updatedAt, now.add(const Duration(days: 400)));
    },
  );

  test(
    'Concurrent saves serialize revisions and reads observe completed writes',
    () async {
      final repository = HivePortfolioDraftRepository(box, clock: () => now);
      final writes = [
        for (var index = 1; index <= 8; index++)
          repository.saveNotes('notes $index'),
      ];
      final reading = repository.read();
      final results = await Future.wait(writes);
      expect(results.map((draft) => draft.revision), [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(results.first.notes, 'notes 1');
      expect((await reading)!.notes, 'notes 8');
      expect((await repository.read())!.revision, 8);
    },
  );

  test('Cache clearing in its own box cannot remove pending draft', () async {
    final cache = await Hive.openBox<dynamic>(
      'github_cache',
      path: directory.path,
    );
    await cache.put('draft', 'an unrelated cached response');
    final repository = HivePortfolioDraftRepository(box, clock: () => now);
    await repository.saveNotes('Private local note');
    await cache.clear();
    expect((await repository.read())!.notes, 'Private local note');
    expect((await repository.read())!.pendingSync, isTrue);
  });

  final brokenRecords = <String, dynamic>{
    'invalid JSON': '{not JSON',
    'wrong storage type': <String>['notes'],
    'null record': null,
    'wrong JSON root': '[]',
    'missing notes': jsonEncode(_envelope(now)..remove('notes')),
    'wrong notes': jsonEncode(_envelope(now)..['notes'] = 123),
    'negative revision': jsonEncode(_envelope(now)..['revision'] = -1),
    'fractional revision': jsonEncode(_envelope(now)..['revision'] = 1.5),
    'missing pending marker': jsonEncode(_envelope(now)..remove('pendingSync')),
    'wrong pending marker': jsonEncode(
      _envelope(now)..['pendingSync'] = 'true',
    ),
    'missing timestamp': jsonEncode(_envelope(now)..remove('updatedAt')),
    'invalid timestamp': jsonEncode(
      _envelope(now)..['updatedAt'] = 'not a date',
    ),
    'overflow timestamp': jsonEncode(
      _envelope(now)..['updatedAt'] = '2026-02-31T00:00:00.000Z',
    ),
    'non UTC timestamp': jsonEncode(
      _envelope(now)..['updatedAt'] = '2026-10-03T12:00:00.000',
    ),
    'wrong schema type': jsonEncode(_envelope(now)..['schemaVersion'] = '1'),
  };
  for (final entry in brokenRecords.entries) {
    test(
      'Corrupt ${entry.key} is retained and cannot be overwritten',
      () async {
        await box.put('draft', entry.value);
        final repository = HivePortfolioDraftRepository(box);
        await expectLater(
          repository.read(),
          throwsA(_failure(PortfolioDraftFailureKind.corrupted)),
        );
        await expectLater(
          repository.saveNotes('overwrite'),
          throwsA(_failure(PortfolioDraftFailureKind.corrupted)),
        );
        expect(box.containsKey('draft'), isTrue);
        expect(box.get('draft'), entry.value);
      },
    );
  }

  for (final version in [
    0,
    HivePortfolioDraftRepository.schemaVersion + 1,
    999,
  ]) {
    test(
      'Unknown schema version $version is preserved for explicit migration',
      () async {
        final raw = jsonEncode(_envelope(now)..['schemaVersion'] = version);
        await box.put('draft', raw);
        final repository = HivePortfolioDraftRepository(box);
        await expectLater(
          repository.read(),
          throwsA(_failure(PortfolioDraftFailureKind.unsupportedVersion)),
        );
        await expectLater(
          repository.saveNotes('overwrite'),
          throwsA(_failure(PortfolioDraftFailureKind.unsupportedVersion)),
        );
        expect(box.get('draft'), raw);
      },
    );
  }

  test(
    'Failed backend write leaves previous draft and successful revision intact',
    () async {
      final rejecting = _WriteFailureBox(box);
      final repository = HivePortfolioDraftRepository(
        rejecting,
        clock: () => now,
      );
      await repository.saveNotes('Durable');
      rejecting.failWrites = true;
      await expectLater(
        repository.saveNotes('Not durable'),
        throwsA(_failure(PortfolioDraftFailureKind.unavailable)),
      );
      expect((await repository.read())!.notes, 'Durable');
      expect((await repository.read())!.revision, 1);
      rejecting.failWrites = false;
      expect((await repository.saveNotes('Recovered')).revision, 2);
    },
  );

  test('Closed box returns typed storage failure on read and write', () async {
    final repository = HivePortfolioDraftRepository(box);
    await box.close();
    await expectLater(
      repository.read(),
      throwsA(_failure(PortfolioDraftFailureKind.unavailable)),
    );
    await expectLater(
      repository.saveNotes('Retry later'),
      throwsA(_failure(PortfolioDraftFailureKind.unavailable)),
    );
  });

  test(
    'Nullable timestamp in schema v1 round-trips without fabricating time',
    () async {
      await box.put('draft', jsonEncode(_envelope(now)..['updatedAt'] = null));
      expect(
        (await HivePortfolioDraftRepository(box).read())!.updatedAt,
        isNull,
      );
    },
  );

  test('Draft validates revision, normalizes UTC and cannot be mutated', () {
    expect(
      () => PortfolioDraft(
        notes: '',
        revision: -1,
        updatedAt: null,
        pendingSync: true,
      ),
      throwsRangeError,
    );
    final localTime = DateTime(2026, 10, 3, 15);
    final draft = PortfolioDraft(
      notes: 'Stable',
      revision: 0,
      updatedAt: localTime,
      pendingSync: true,
    );
    expect(draft.updatedAt!.isUtc, isTrue);
    expect(draft.updatedAt, localTime.toUtc());
    expect(() => (draft as dynamic).notes = 'Mutated', throwsNoSuchMethodError);
  });

  test(
    'Memory repository is explicitly isolated from persistent source',
    () async {
      final first = MemoryPortfolioDraftRepository(clock: () => now);
      final second = MemoryPortfolioDraftRepository();
      await first.saveNotes('Test source');
      expect(await second.read(), isNull);
      expect(await HivePortfolioDraftRepository(box).read(), isNull);
      expect((await first.read())!.pendingSync, isTrue);
    },
  );
}

Map<String, dynamic> _envelope(DateTime now) => {
  'schemaVersion': 1,
  'notes': 'Stored notes',
  'revision': 1,
  'updatedAt': now.toIso8601String(),
  'pendingSync': true,
};

Matcher _failure(PortfolioDraftFailureKind kind) => isA<PortfolioDraftFailure>()
    .having((failure) => failure.kind, 'kind', kind);

class _WriteFailureBox implements Box<dynamic> {
  _WriteFailureBox(this.delegate);
  final Box<dynamic> delegate;
  bool failWrites = false;

  @override
  bool containsKey(dynamic key) => delegate.containsKey(key);

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);

  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (failWrites) throw const FileSystemException('Simulated write failure');
    await delegate.put(key, value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
