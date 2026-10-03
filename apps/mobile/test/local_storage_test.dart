import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:app_stackcard/core/storage/local_storage.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stackcard-local-');
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('two boxes restore independently after closing and reopening', () async {
    var storage = await LocalStorage.open(directory: directory);
    await storage.githubResponses.put('public-source', 'cached response');
    await storage.portfolioDraft.put('draft', 'unsynchronised notes');
    await storage.close();

    storage = await LocalStorage.open(directory: directory);
    expect(storage.githubResponses.get('public-source'), 'cached response');
    expect(storage.portfolioDraft.get('draft'), 'unsynchronised notes');
    await storage.githubResponses.clear();
    expect(storage.portfolioDraft.get('draft'), 'unsynchronised notes');
    await storage.close();
  });

  test(
    'corrupt cache file is preserved and rebuilt without changing draft',
    () async {
      var storage = await LocalStorage.open(directory: directory);
      await storage.githubResponses.put('public-source', 'cached response');
      await storage.portfolioDraft.put('draft', 'keep my notes');
      await storage.close();
      final cacheFile = File(
        '${directory.path}/stackcard/github_responses.hive',
      );
      final corrupted = await cacheFile.readAsBytes();
      corrupted[corrupted.length - 1] ^= 0xff;
      await cacheFile.writeAsBytes(corrupted, flush: true);

      storage = await LocalStorage.open(directory: directory);
      expect(storage.githubResponses.isEmpty, isTrue);
      expect(storage.portfolioDraft.get('draft'), 'keep my notes');
      final preserved = await Directory('${directory.path}/stackcard')
          .list()
          .where((entry) => entry.path.contains('.unreadable-'))
          .toList();
      expect(preserved, hasLength(1));
      expect(await File(preserved.single.path).readAsBytes(), corrupted);
      await storage.close();
    },
  );

  test('corrupt draft file stays intact and startup fails safely', () async {
    final storage = await LocalStorage.open(directory: directory);
    await storage.portfolioDraft.put('draft', 'keep my notes');
    await storage.close();
    final draftFile = File('${directory.path}/stackcard/portfolio_draft.hive');
    final corrupted = await draftFile.readAsBytes();
    corrupted[corrupted.length - 1] ^= 0xff;
    await draftFile.writeAsBytes(corrupted, flush: true);

    await expectLater(
      LocalStorage.open(directory: directory),
      throwsA(isA<HiveError>()),
    );
    expect(await draftFile.readAsBytes(), corrupted);
    expect(Hive.isBoxOpen('github_responses'), isFalse);
  });

  test('cache close failure still closes the draft box', () async {
    final storage = await LocalStorage.open(directory: directory);
    await storage.portfolioDraft.put('draft', 'keep my notes');
    await File('${directory.path}/stackcard/github_responses.lock').delete();

    await expectLater(storage.close(), throwsA(isA<FileSystemException>()));
    expect(storage.portfolioDraft.isOpen, isFalse);
    final restored = await LocalStorage.open(directory: directory);
    expect(restored.portfolioDraft.get('draft'), 'keep my notes');
    await restored.close();
  });
}
