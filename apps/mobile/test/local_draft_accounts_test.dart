import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/features/portfolio_draft/data/local_draft_accounts.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late LocalDraftAccounts accounts;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stackcard-accounts-');
    box = await Hive.openBox<dynamic>('accounts', path: directory.path);
    accounts = LocalDraftAccounts(box);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> reopen() async {
    await box.close();
    box = await Hive.openBox<dynamic>('accounts', path: directory.path);
    accounts = LocalDraftAccounts(box);
  }

  test(
    'Guest, A and B isolate content, notes and revisions across reopen',
    () async {
      final guest = accounts.guestRepository;
      final a = accounts.repositoryForUser('uid/A');
      final b = accounts.repositoryForUser('uid/B');
      final content = PortfolioContent(resumeText: 'Private A\nresume');
      await guest.saveNotes('Private guest');
      await a.save(content, expectedRevision: 0, notes: 'Private A');
      await a.saveNotes('Edited A');
      await b.saveNotes('Private B');
      await reopen();
      expect((await accounts.guestRepository.read())!.notes, 'Private guest');
      final savedA = (await accounts.repositoryForUser('uid/A').read())!;
      expect(savedA.notes, 'Edited A');
      expect(savedA.content, content);
      expect(savedA.revision, 2);
      expect(savedA.pendingSync, isTrue);
      expect(
        (await accounts.repositoryForUser('uid/B').read())!.notes,
        'Private B',
      );
      expect((await accounts.repositoryForUser('uid/B').read())!.revision, 1);
      expect(await accounts.repositoryForUser('new user').read(), isNull);
      expect(box.keys.every((key) => !(key as String).contains('/')), isTrue);
    },
  );

  test(
    'Same key from different repository instances serializes revisions',
    () async {
      final first = accounts.repositoryForUser('A');
      final second = accounts.repositoryForUser('A');
      final saved = await Future.wait([
        first.saveNotes('first'),
        second.saveNotes('second'),
        first.saveNotes('third'),
      ]);
      expect(saved.map((draft) => draft.revision), [1, 2, 3]);
      final winning = first.save(
        PortfolioContent(),
        expectedRevision: 3,
        notes: 'winner',
      );
      final stale = second.save(
        PortfolioContent(),
        expectedRevision: 3,
        notes: 'stale',
      );
      await expectLater(
        stale,
        throwsA(_failure(PortfolioDraftFailureKind.conflict)),
      );
      expect((await winning).revision, 4);
      expect((await first.read())!.notes, 'winner');
    },
  );

  test(
    'Explicit transfer preserves exact current envelope and metadata',
    () async {
      final content = PortfolioContent(resumeText: 'Secret resume');
      await accounts.guestRepository.save(
        content,
        expectedRevision: 0,
        notes: 'private',
      );
      final original = box.get('draft');
      expect(await accounts.repositoryForUser('A').read(), isNull);
      expect(await accounts.hasGuestDraft(), isTrue);
      await accounts.transferGuestToUser('A');
      expect(box.get(_key('A')), original);
      expect(box.containsKey('draft'), isFalse);
      expect(await accounts.guestRepository.read(), isNull);
      expect(await accounts.hasGuestDraft(), isFalse);
      await accounts.transferGuestToUser('B');
      await accounts.transferGuestToUser('A');
      await reopen();
      expect((await accounts.repositoryForUser('A').read())!.content, content);
      expect((await accounts.repositoryForUser('A').read())!.revision, 1);
      expect(await accounts.repositoryForUser('B').read(), isNull);
      expect(await accounts.guestRepository.read(), isNull);
    },
  );

  test('Transferred legacy v1 migrates only on explicit owner save', () async {
    final raw = _v1('  Legacy notes\n  ', revision: 8);
    await box.put('draft', raw);
    await accounts.transferGuestToUser('A');
    expect(box.get(_key('A')), raw);
    expect(box.containsKey('${_key('A')}.v1.backup'), isFalse);
    final saved = (await accounts.repositoryForUser('A').read())!;
    expect(saved.revision, 8);
    expect(saved.updatedAt, isNull);
    expect(saved.content, isNull);
    await accounts.repositoryForUser('A').saveNotes('New notes');
    expect(box.get('${_key('A')}.v1.backup'), raw);
    expect((await accounts.repositoryForUser('A').read())!.revision, 9);
    expect(box.containsKey('draft.v1.backup'), isFalse);
    await reopen();
    expect(box.get('${_key('A')}.v1.backup'), raw);
  });

  test('Migrated guest carries its original v1 backup unchanged', () async {
    final raw = _v1('Original');
    await box.put('draft', raw);
    await accounts.guestRepository.saveNotes('Current');
    final current = box.get('draft');
    await accounts.transferGuestToUser('A');
    expect(box.get(_key('A')), current);
    expect(box.get('${_key('A')}.v1.backup'), raw);
    expect(box.containsKey('draft.v1.backup'), isFalse);
    await reopen();
    expect((await accounts.repositoryForUser('A').read())!.notes, 'Current');
    expect(box.get('${_key('A')}.v1.backup'), raw);
  });

  test('Occupied owner or backup never overwrites either side', () async {
    await accounts.guestRepository.saveNotes('guest');
    await accounts.repositoryForUser('A').saveNotes('owner');
    final guestRaw = box.get('draft');
    final ownerRaw = box.get(_key('A'));
    await expectLater(
      accounts.transferGuestToUser('A'),
      throwsA(_failure(PortfolioDraftFailureKind.conflict)),
    );
    expect(box.get('draft'), guestRaw);
    expect(box.get(_key('A')), ownerRaw);
    await box.put('${_key('B')}.v1.backup', _v1('orphan'));
    await expectLater(
      accounts.transferGuestToUser('B'),
      throwsA(_failure(PortfolioDraftFailureKind.conflict)),
    );
    expect(box.get('draft'), guestRaw);
    expect(box.containsKey(_key('B')), isFalse);
  });

  for (final target in ['draft', _key('A')]) {
    for (final record in [
      'invalid-json',
      jsonEncode({'schemaVersion': 99}),
    ]) {
      test('Corrupt/unsupported $target blocks transfer: $record', () async {
        await accounts.guestRepository.saveNotes('guest');
        await box.put(target, record);
        final before = {for (final key in box.keys) key: box.get(key)};
        await expectLater(
          accounts.transferGuestToUser('A'),
          throwsA(isA<PortfolioDraftFailure>()),
        );
        expect({for (final key in box.keys) key: box.get(key)}, before);
      });
    }
  }

  test(
    'Corrupt guest backup prevents transfer without mutating records',
    () async {
      await accounts.guestRepository.saveNotes('guest');
      await box.put('draft.v1.backup', '{broken');
      final raw = box.get('draft');
      await expectLater(
        accounts.transferGuestToUser('A'),
        throwsA(_failure(PortfolioDraftFailureKind.corrupted)),
      );
      expect(box.get('draft'), raw);
      expect(box.get('draft.v1.backup'), '{broken');
      expect(box.containsKey(_key('A')), isFalse);
    },
  );

  test('Legacy mismatching backup cannot be adopted', () async {
    await box.put('draft', _v1('source'));
    await box.put('draft.v1.backup', _v1('different'));
    await expectLater(
      accounts.transferGuestToUser('A'),
      throwsA(_failure(PortfolioDraftFailureKind.corrupted)),
    );
    expect(box.containsKey(_key('A')), isFalse);
    expect(box.containsKey('draft.guest.transfer'), isFalse);
  });

  test('Queued guest save cannot resurrect transferred A content', () async {
    final guest = accounts.guestRepository;
    await guest.saveNotes('belongs to A');
    final transfer = accounts.transferGuestToUser('A');
    final obsoleteSave = guest.saveNotes('queued A content');
    await expectLater(
      obsoleteSave,
      throwsA(_failure(PortfolioDraftFailureKind.conflict)),
    );
    await transfer;
    expect(await accounts.guestRepository.read(), isNull);
    expect(
      (await accounts.repositoryForUser('A').read())!.notes,
      'belongs to A',
    );
    await accounts.transferGuestToUser('B');
    expect(await accounts.repositoryForUser('B').read(), isNull);
    await accounts.guestRepository.saveNotes('new independent guest');
    await accounts.transferGuestToUser('B');
    expect(
      (await accounts.repositoryForUser('B').read())!.notes,
      'new independent guest',
    );
    expect(
      (await accounts.repositoryForUser('A').read())!.notes,
      'belongs to A',
    );
  });

  test('In-flight account save stays bound to its original key', () async {
    final gated = _FaultBox(box)..pauseKey = _key('A');
    final local = LocalDraftAccounts(gated);
    final aWrite = local.repositoryForUser('A').saveNotes('A in flight');
    await gated.entered.future;
    final bWrite = local.repositoryForUser('B').saveNotes('B active');
    gated.release.complete();
    await Future.wait([aWrite, bWrite]);
    expect((await local.repositoryForUser('A').read())!.notes, 'A in flight');
    expect((await local.repositoryForUser('B').read())!.notes, 'B active');
    expect(await local.guestRepository.read(), isNull);
  });

  // Real-Hive failures at reservation, destination/backup, ownership claim,
  // generation tombstone and each cleanup operation.
  for (var stage = 1; stage <= 8; stage++) {
    test(
      'Mutation $stage failure preserves ownership and resumes after reopen',
      () async {
        final legacy = _v1('backup');
        await box.put('draft', legacy);
        await accounts.guestRepository.saveNotes('guest durable');
        final sourceRaw = box.get('draft');
        final fault = _FaultBox(box)..failMutation = stage;
        final local = LocalDraftAccounts(fault);
        await expectLater(
          local.transferGuestToUser('A'),
          throwsA(_failure(PortfolioDraftFailureKind.unavailable)),
        );
        if (stage <= 6) expect(box.get('draft'), sourceRaw);
        await reopen();
        if (stage > 1) {
          expect(await accounts.hasGuestDraft(forUid: 'A'), isTrue);
          expect(await accounts.hasGuestDraft(forUid: 'B'), isFalse);
          await expectLater(
            accounts.transferGuestToUser('B'),
            throwsA(_failure(PortfolioDraftFailureKind.conflict)),
          );
          await expectLater(
            accounts.guestRepository.read(),
            throwsA(_failure(PortfolioDraftFailureKind.conflict)),
          );
          await expectLater(
            accounts.repositoryForUser('A').saveNotes('ambiguous'),
            throwsA(_failure(PortfolioDraftFailureKind.conflict)),
          );
        }
        await accounts.transferGuestToUser('A');
        expect(box.get(_key('A')), sourceRaw);
        expect(box.get('${_key('A')}.v1.backup'), legacy);
        expect(await accounts.guestRepository.read(), isNull);
        expect(await accounts.repositoryForUser('B').read(), isNull);
        expect(box.containsKey('draft.guest.transfer'), isFalse);
        await reopen();
        expect(
          (await accounts.repositoryForUser('A').read())!.notes,
          'guest durable',
        );
        expect(await accounts.hasGuestDraft(), isFalse);
      },
    );
  }

  test(
    'Malformed journal refuses ambiguous guest and account access',
    () async {
      await accounts.guestRepository.saveNotes('guest');
      await box.put('draft.guest.transfer', '{broken');
      await expectLater(
        accounts.hasGuestDraft(),
        throwsA(_failure(PortfolioDraftFailureKind.corrupted)),
      );
      await expectLater(
        accounts.repositoryForUser('B').read(),
        throwsA(_failure(PortfolioDraftFailureKind.corrupted)),
      );
      await expectLater(
        accounts.transferGuestToUser('A'),
        throwsA(_failure(PortfolioDraftFailureKind.corrupted)),
      );
      expect(box.get('draft.guest.transfer'), '{broken');
    },
  );

  for (var stage = 1; stage <= 8; stage++) {
    test('Flush $stage failure remains recoverable after reopen', () async {
      final backup = _v1('original');
      await box.put('draft', backup);
      await accounts.guestRepository.saveNotes('durable source');
      final raw = box.get('draft');
      final fault = _FaultBox(box)..failFlush = stage;
      await expectLater(
        LocalDraftAccounts(fault).transferGuestToUser('A'),
        throwsA(_failure(PortfolioDraftFailureKind.unavailable)),
      );
      await reopen();
      if (stage < 8) {
        await expectLater(
          accounts.transferGuestToUser('B'),
          throwsA(_failure(PortfolioDraftFailureKind.conflict)),
        );
      }
      await accounts.transferGuestToUser('A');
      expect(box.get(_key('A')), raw);
      expect(box.get('${_key('A')}.v1.backup'), backup);
      expect(await accounts.guestRepository.read(), isNull);
      expect(await accounts.repositoryForUser('B').read(), isNull);
    });
  }

  test('Unicode and path-like UIDs use distinct encoded keys', () async {
    for (final uid in ['../draft', 'a/b', 'a_b', 'пользователь 🧑', 'A']) {
      await accounts.repositoryForUser(uid).saveNotes(uid);
    }
    await reopen();
    for (final uid in ['../draft', 'a/b', 'a_b', 'пользователь 🧑', 'A']) {
      expect((await accounts.repositoryForUser(uid).read())!.notes, uid);
    }
    expect(() => accounts.repositoryForUser(''), throwsArgumentError);
    expect(box.containsKey('draft'), isFalse);
  });
}

String _key(String uid) =>
    'draft.user.${base64Url.encode(utf8.encode(uid)).replaceAll('=', '')}';
String _v1(String notes, {int revision = 3}) => jsonEncode({
  'schemaVersion': 1,
  'notes': notes,
  'revision': revision,
  'updatedAt': null,
  'pendingSync': true,
});
Matcher _failure(PortfolioDraftFailureKind kind) => isA<PortfolioDraftFailure>()
    .having((failure) => failure.kind, 'kind', kind);

class _FaultBox implements Box<dynamic> {
  _FaultBox(this.delegate);
  final Box<dynamic> delegate;
  int? failMutation;
  int mutations = 0;
  int? failFlush;
  int flushes = 0;
  String? pauseKey;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  bool containsKey(dynamic key) => delegate.containsKey(key);
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, dynamic value) async {
    _maybeFail();
    if (key == pauseKey) {
      entered.complete();
      await release.future;
    }
    await delegate.put(key, value);
  }

  @override
  Future<void> delete(dynamic key) async {
    _maybeFail();
    await delegate.delete(key);
  }

  @override
  Future<void> flush() async {
    flushes++;
    if (flushes == failFlush) {
      throw const FileSystemException('Simulated flush failure');
    }
    await delegate.flush();
  }

  void _maybeFail() {
    mutations++;
    if (mutations == failMutation) {
      throw const FileSystemException('Simulated transaction failure');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
