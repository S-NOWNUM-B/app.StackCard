// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:app_stackcard/app/local_runtime.dart';
import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/core/state/settings_repository.dart';
import 'package:app_stackcard/core/storage/local_storage.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_history_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_history_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final _time = DateTime.utc(2026, 11, 16, 10);

PortfolioProject _project(String id, {String description = 'Описание'}) =>
    PortfolioProject(
      id: id,
      title: 'Проект $id',
      description: description,
      technologies: const ['Dart'],
    );

/// Workspace с main-документом: проекты — в Library, документ ссылается на них.
PortfolioContent _workspace({
  String name = 'Имя',
  List<String> projects = const ['p1'],
  List<String> skills = const ['Dart'],
  String avatar = '',
}) {
  final library = [for (final id in projects) _project(id)];
  return PortfolioContent(
    projects: library,
    mainPortfolioId: 'main',
    documents: [
      PortfolioDocument(
        id: 'main',
        title: 'Основное',
        kind: PortfolioDocumentKind.portfolio,
        createdAt: _time,
        updatedAt: _time,
        content: PortfolioContent(
          profile: PortfolioProfile(name: name, avatarPath: avatar),
          skills: [
            for (final skill in skills) Skill(id: 's-$skill', name: skill),
          ],
        ),
        projects: [
          for (final id in projects) PortfolioProjectAttachment(projectId: id),
        ],
      ),
    ],
  );
}

void main() {
  group('domain', () {
    test('Snapshot resolves projects and never copies the avatar', () {
      final snapshot = buildPortfolioSnapshot(
        workspace: _workspace(avatar: 'accounts/u/media/a.jpg'),
        at: _time,
        id: '1',
      )!;
      expect(snapshot.hasAvatar, isTrue);
      expect(snapshot.content.profile.avatarPath, isEmpty);
      expect(snapshot.content.profile.avatarUrl, isEmpty);
      expect(snapshot.content.projects.single.id, 'p1');
      expect(snapshot.attachments.single.projectId, 'p1');
    });

    test(
      'No main document or a dangling project reference gives no snapshot',
      () {
        expect(
          buildPortfolioSnapshot(
            workspace: PortfolioContent(),
            at: _time,
            id: '1',
          ),
          isNull,
        );
        final dangling = _workspace().copyWith(projects: const []);
        expect(
          buildPortfolioSnapshot(workspace: dangling, at: _time, id: '1'),
          isNull,
        );
      },
    );

    test('An identical consecutive snapshot is not added', () {
      PortfolioSnapshot make(String id, String name) => buildPortfolioSnapshot(
        workspace: _workspace(name: name),
        at: _time,
        id: id,
      )!;
      final first = appendPortfolioSnapshot(const [], make('1', 'A'));
      expect(appendPortfolioSnapshot(first, make('2', 'A')), same(first));
      expect(appendPortfolioSnapshot(first, make('3', 'B')), hasLength(2));
    });

    test('More than the limit evicts the oldest, newest first', () {
      var list = <PortfolioSnapshot>[];
      for (var index = 0; index < portfolioHistoryLimit + 5; index++) {
        list = appendPortfolioSnapshot(
          list,
          buildPortfolioSnapshot(
            workspace: _workspace(name: 'v$index'),
            at: _time.add(Duration(minutes: index)),
            id: '$index',
          )!,
        );
      }
      expect(list, hasLength(portfolioHistoryLimit));
      expect(list.first.content.profile.name, 'v24');
      expect(list.last.content.profile.name, 'v5');
    });

    test(
      'Restore keeps the current avatar and skips deleted library projects',
      () {
        final old = buildPortfolioSnapshot(
          workspace: _workspace(name: 'Старое', projects: ['p1', 'gone']),
          at: _time,
          id: '1',
        )!;
        final current = _workspace(
          name: 'Новое',
          avatar: 'accounts/u/media/new.jpg',
        );
        final result = restorePortfolioSnapshot(
          workspace: current,
          current: mainPortfolioDocument(current)!,
          snapshot: old,
        );
        final document = result.document;
        expect(document.content.profile.name, 'Старое');
        expect(document.content.profile.avatarPath, 'accounts/u/media/new.jpg');
        expect(document.content.projects, isEmpty);
        expect(document.projects.map((item) => item.projectId), ['p1']);
        expect(result.skippedProjects, 1);
        // Откат ничего не пишет: исходный workspace не изменился.
        expect(mainPortfolioDocument(current)!.content.profile.name, 'Новое');
      },
    );

    test(
      'Summary reports counts and what changed since the previous version',
      () {
        PortfolioSnapshot make(PortfolioContent workspace, String id) =>
            buildPortfolioSnapshot(workspace: workspace, at: _time, id: id)!;
        final before = make(_workspace(), '1');
        final after = make(
          _workspace(name: 'Другое', projects: ['p1', 'p2'], skills: ['Rust']),
          '2',
        );
        final summary = summarizePortfolioSnapshot(after, previous: before);
        expect(summary.projects, 2);
        expect(summary.skills, 1);
        expect(summary.changes.map((change) => change.kind), [
          PortfolioSnapshotChangeKind.profile,
          PortfolioSnapshotChangeKind.projectsAdded,
          PortfolioSnapshotChangeKind.skillsAdded,
          PortfolioSnapshotChangeKind.skillsRemoved,
        ]);
        expect(summarizePortfolioSnapshot(before).changes, isEmpty);
      },
    );
  });

  group('memory repository', () {
    test('Records, dedupes and clears', () async {
      final repository = MemoryPortfolioHistoryRepository();
      await repository.record(PortfolioContent(), _time);
      expect(await repository.list(), isEmpty);
      await repository.record(_workspace(), _time);
      await repository.record(_workspace(), _time);
      expect(await repository.list(), hasLength(1));
      await repository.clear();
      expect(await repository.list(), isEmpty);
    });
  });

  group('hive repository', () {
    late Directory directory;
    late Box<dynamic> box;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('stackcard-history-');
      box = await Hive.openBox<dynamic>('history', path: directory.path);
    });

    tearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    test('Snapshots survive reopening and read without writing', () async {
      await HivePortfolioHistoryRepository(box).record(_workspace(), _time);
      final raw = box.get(HivePortfolioHistoryRepository.guestKey);
      final list = await HivePortfolioHistoryRepository(box).list();
      expect(list.single.content.profile.name, 'Имя');
      expect(list.single.savedAt, _time);
      expect(box.get(HivePortfolioHistoryRepository.guestKey), raw);
    });

    test('The limit evicts the oldest and persists newest first', () async {
      final repository = HivePortfolioHistoryRepository(box);
      for (var index = 0; index < portfolioHistoryLimit + 3; index++) {
        await repository.record(
          _workspace(name: 'v$index'),
          _time.add(Duration(minutes: index)),
        );
      }
      final list = await HivePortfolioHistoryRepository(box).list();
      expect(list, hasLength(portfolioHistoryLimit));
      expect(list.first.content.profile.name, 'v22');
      expect(list.last.content.profile.name, 'v3');
    });

    test(
      'Owners are isolated: guest, two UIDs; clear touches only one',
      () async {
        final guest = HivePortfolioHistoryRepository(box);
        final first = HivePortfolioHistoryRepository(box, uid: 'u1');
        final second = HivePortfolioHistoryRepository(box, uid: 'u2');
        await guest.record(_workspace(name: 'guest'), _time);
        await first.record(_workspace(name: 'one'), _time);
        await second.record(_workspace(name: 'two'), _time);
        expect((await first.list()).single.content.profile.name, 'one');
        expect((await second.list()).single.content.profile.name, 'two');
        expect((await guest.list()).single.content.profile.name, 'guest');
        await first.clear();
        expect(await first.list(), isEmpty);
        expect(await second.list(), hasLength(1));
        expect(await guest.list(), hasLength(1));
      },
    );

    test('Avatar bytes and paths are not stored in the box', () async {
      await HivePortfolioHistoryRepository(
        box,
      ).record(_workspace(avatar: 'accounts/u/media/secret-avatar.jpg'), _time);
      final raw = box.get(HivePortfolioHistoryRepository.guestKey) as String;
      expect(raw, isNot(contains('secret-avatar')));
      expect(raw, contains('"hasAvatar":true'));
    });

    test(
      'Corrupted or unsupported records fail reading, never crash Save',
      () async {
        final repository = HivePortfolioHistoryRepository(box);
        for (final value in <Object?>[
          '{broken',
          '[]',
          '{"schemaVersion":99,"entries":[]}',
          42,
        ]) {
          await box.put(HivePortfolioHistoryRepository.guestKey, value);
          await expectLater(
            repository.list(),
            throwsA(isA<PortfolioHistoryFailure>()),
          );
          // Новый Save заменяет повреждённую историю.
          await repository.record(_workspace(), _time);
          expect(await repository.list(), hasLength(1));
        }
      },
    );

    test('A workspace without a main document records nothing', () async {
      final repository = HivePortfolioHistoryRepository(box);
      await repository.record(PortfolioContent(), _time);
      expect(box.containsKey(HivePortfolioHistoryRepository.guestKey), isFalse);
    });
  });

  group('storage and account cleanup', () {
    late Directory directory;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      directory = await Directory.systemTemp.createTemp('stackcard-hist-rt-');
    });

    tearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    test('History lives in its own box and survives reopening', () async {
      var storage = await LocalStorage.open(directory: directory);
      await storage.portfolioDraft.put('draft', 'keep');
      await HivePortfolioHistoryRepository(storage.portfolioHistory)
          .record(_workspace(), _time);
      await storage.close();
      storage = await LocalStorage.open(directory: directory);
      expect(storage.portfolioDraft.get('history.guest'), isNull);
      expect(
        await HivePortfolioHistoryRepository(storage.portfolioHistory).list(),
        hasLength(1),
      );
      await storage.close();
    });

    test('Confirmed account deletion clears that UID history only', () async {
      final storage = await LocalStorage.open(directory: directory);
      final runtime = LocalRuntime(
        settings: const AppSettings(),
        settingsRepository: _Settings(),
        storage: storage,
      );
      for (final uid in <String?>['gone', 'stay', null]) {
        await runtime.historyRepositoryForUser(uid).record(_workspace(), _time);
      }
      await runtime.clearConfirmedDeletedUser('gone');
      expect(await runtime.historyRepositoryForUser('gone').list(), isEmpty);
      expect(
        await runtime.historyRepositoryForUser('stay').list(),
        hasLength(1),
      );
      expect(await runtime.historyRepositoryForUser(null).list(), hasLength(1));
      await storage.close();
    });

    test('Guest transfer to an account drops the guest history', () async {
      final storage = await LocalStorage.open(directory: directory);
      final runtime = LocalRuntime(
        settings: const AppSettings(),
        settingsRepository: _Settings(),
        storage: storage,
      );
      await runtime.historyRepositoryForUser(null).record(_workspace(), _time);
      await runtime
          .historyRepositoryForUser('other')
          .record(_workspace(), _time);
      await runtime.transferGuestToUser('u');
      expect(await runtime.historyRepositoryForUser(null).list(), isEmpty);
      expect(
        await runtime.historyRepositoryForUser('other').list(),
        hasLength(1),
      );
      await storage.close();
    });

    test('Sign-out cleanup removes the signed-out UID history', () async {
      final storage = await LocalStorage.open(directory: directory);
      final runtime = LocalRuntime(
        settings: const AppSettings(),
        settingsRepository: _Settings(),
        storage: storage,
      );
      await runtime.historyRepositoryForUser('u').record(_workspace(), _time);
      await runtime.clearHistoryForUser('u');
      expect(await runtime.historyRepositoryForUser('u').list(), isEmpty);
      await storage.close();
    });
  });
}

class _Settings implements SettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings();
  @override
  Future<void> save(AppSettings settings) async {}
}
