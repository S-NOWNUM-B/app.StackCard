import 'dart:io';

import 'package:app_stackcard/app/local_runtime.dart';
import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/core/state/settings_repository.dart';
import 'package:app_stackcard/features/github_import/github_import.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  test('runtime restores settings and durable draft after reopening', () async {
    final directory = await Directory.systemTemp.createTemp(
      'stackcard-runtime-',
    );
    final settings = _SettingsStore(
      const AppSettings(
        theme: AppTheme.light,
        language: AppLanguage.en,
        showSourceDescriptions: false,
      ),
    );
    final first = await LocalRuntime.load(
      directory: directory,
      settingsRepository: settings,
    );
    await first.draftRepository.saveNotes('Durable local ideas');
    await first.storage.close();
    final second = await LocalRuntime.load(
      directory: directory,
      settingsRepository: settings,
    );
    expect(second.settings, settings.value);
    final draft = await second.draftRepository.read();
    expect(draft?.notes, 'Durable local ideas');
    expect(draft?.pendingSync, isTrue);
    expect(draft?.revision, 1);
    await second.storage.close();
    await directory.delete(recursive: true);
  });

  testWidgets('startup failure shows safe retry and preserves error details', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      StackCardBootstrap(
        loadRuntime: () async {
          attempts++;
          throw const FileSystemException('private diagnostic path');
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Локальные данные недоступны'), findsOneWidget);
    expect(find.textContaining('private diagnostic'), findsNothing);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'saved source notice, translations and description preference reflect current snapshot',
    (tester) async {
      final source = _CachedSource();
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/github-import',
          initialSettings: const AppSettings(
            language: AppLanguage.en,
            showSourceDescriptions: false,
          ),
          providerOverrides: [
            githubImportRepositoryProvider.overrideWithValue(source),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('github_username')),
        'octocat',
      );
      await tester.tap(find.text('Load profile'));
      await tester.pumpAndSettle();
      expect(find.text('Saved GitHub copy'), findsOneWidget);
      expect(find.textContaining('Last checked:'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('alpha'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('github_import_list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Source description'), findsNothing);
      source.fromCache = false;
      await tester.ensureVisible(find.text('Refresh GitHub'));
      await tester.tap(find.text('Refresh GitHub'));
      await tester.pumpAndSettle();
      expect(find.text('Saved GitHub copy'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  tearDownAll(Hive.close);
}

class _SettingsStore implements SettingsRepository {
  _SettingsStore(this.value);
  AppSettings value;
  @override
  Future<AppSettings> load() async => value;
  @override
  Future<void> save(AppSettings settings) async => value = settings;
}

class _CachedSource implements GitHubImportRepository {
  bool fromCache = true;
  GitHubReadMetadata get metadata => GitHubReadMetadata(
    fromCache: fromCache,
    validatedAt: DateTime.utc(2026, 10, 3, 10),
    fallbackFailure: fromCache
        ? const GitHubFailure(GitHubFailureKind.network)
        : null,
  );
  @override
  Future<GitHubProfile> getProfile(String username) async => GitHubProfile(
    id: 1,
    login: username,
    htmlUrl: 'https://github.com/$username',
    publicRepositories: 1,
    readMetadata: metadata,
  );
  @override
  Future<GitHubRepositoriesPage> getRepositories(
    GitHubProfile profile, {
    Uri? page,
  }) async => GitHubRepositoriesPage(
    readMetadata: metadata,
    repositories: [
      GitHubRepository(
        id: 1,
        name: 'alpha',
        fullName: '${profile.login}/alpha',
        description: 'Source description',
        htmlUrl: 'https://github.com/${profile.login}/alpha',
        stars: 1,
        forks: 0,
        isFork: false,
        archived: false,
        updatedAt: DateTime.utc(2026),
      ),
    ],
  );
  @override
  void cancelRequests() {}
}
