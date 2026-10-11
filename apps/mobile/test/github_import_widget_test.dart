import 'dart:async';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/github_import/github_import.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Linked GitHub selection preview', (tester) async {
    await _open(tester, await _local(), _Source()..pagination = true);
    await _tap(tester, find.byKey(const ValueKey('github_repository_1')));
    if (const bool.fromEnvironment('UPDATE_SINGLE_PORTFOLIO_PREVIEWS')) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '/private/tmp/stackcard-redesign-github-selection.png',
        ),
      );
    }
    expect(tester.takeException(), isNull);
  });

  setUpAll(() async {
    final loader = FontLoader('Manrope');
    for (final font in [
      'Manrope-Regular.ttf',
      'Manrope-SemiBold.ttf',
      'Manrope-Bold.ttf',
      'Manrope-ExtraBold.ttf',
    ]) {
      loader.addFont(rootBundle.load('assets/fonts/$font'));
    }
    await loader.load();
  });

  test(
    'HTTP repository retains rate deadlines across reopened screens',
    () async {
      final container = ProviderContainer.test();
      final first = container.listen(githubImportControllerProvider, (_, _) {});
      final repository = container.read(githubImportRepositoryProvider);
      first.close();
      await container.pump();
      final second = container.listen(
        githubImportControllerProvider,
        (_, _) {},
      );
      expect(container.read(githubImportRepositoryProvider), same(repository));
      expect(container.read(githubImportControllerProvider).profile, isNull);
      second.close();
    },
  );

  testWidgets(
    'Missing GitHub source accepts a profile URL and persists one normalized identity',
    (tester) async {
      final local = await _local(source: '');
      final source = _Source();
      await _open(tester, local, source);
      expect(source.profileReads, 0);
      await tester.tap(find.byKey(const ValueKey('github_source_save')));
      await tester.pumpAndSettle();
      expect(find.text('Добавьте GitHub-профиль'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('github_username')),
        ' https://github.com/Octocat/ ',
      );
      await _tap(tester, find.byKey(const ValueKey('github_source_save')));
      expect((await local.read())!.content!.githubUsername, 'octocat');
      expect((await local.read())!.content!.profile.username, 'existing-slug');
      expect(source.profileReads, 1);
      expect(find.text('@octocat'), findsOneWidget);
      expect(find.byKey(const ValueKey('github_repository_1')), findsOneWidget);
    },
  );

  testWidgets(
    'Bulk import saves Library immediately and leaves unrelated editor data and attachments alone',
    (tester) async {
      final local = await _local();
      final source = _Source();
      final container = await _open(tester, local, source);
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      final working = controller.workingContent!;
      controller.updateContent(
        working.copyWith(
          profile: working.profile.copyWith(bio: 'Unsaved biography'),
        ),
      );
      controller.updateNotes('Unsaved notes');
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('github_repository_1')));
      await _tap(tester, find.byKey(const ValueKey('github_import_selected')));
      final saved = (await local.read())!;
      expect(saved.content!.projects.single.githubRepositoryId, 1);
      expect(saved.content!.projects.single.iconId, 'folder');
      expect(saved.content!.documents, isEmpty);
      expect(saved.content!.profile.bio, 'Saved biography');
      expect(saved.notes, 'Private saved notes');
      expect(controller.workingContent!.profile.bio, 'Unsaved biography');
      expect(
        container.read(portfolioDraftControllerProvider).notes,
        'Unsaved notes',
      );
      expect(
        container.read(portfolioDraftControllerProvider).hasUnsavedChanges,
        isTrue,
      );
      expect(find.text('Уже импортирован'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, local, source);
      expect(find.text('Уже импортирован'), findsOneWidget);
      expect((await local.read())!.content!.projects, hasLength(1));
    },
  );

  testWidgets(
    'Search states its partial scope, real pagination finds another repository and preserves selection',
    (tester) async {
      final local = await _local();
      final source = _Source()..pagination = true;
      final container = await _open(tester, local, source);
      await _tap(tester, find.byKey(const ValueKey('github_repository_1')));
      await tester.enterText(
        find.byKey(const ValueKey('github_search')),
        'later',
      );
      await tester.pump(const Duration(milliseconds: 299));
      expect(container.read(githubImportControllerProvider).query, '');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(
        find.text('На загруженных страницах ничего не найдено'),
        findsOneWidget,
      );
      expect(find.textContaining('загруженн'), findsWidgets);
      await _tap(tester, find.text('Загрузить ещё'));
      expect(source.pageReads, 2);
      expect(
        container.read(githubImportControllerProvider).repositories,
        hasLength(2),
      );
      await _tap(tester, find.byKey(const ValueKey('github_repository_2')));
      await _tap(tester, find.byKey(const ValueKey('github_import_selected')));
      expect(
        (await local.read())!.content!.projects.map(
          (item) => item.githubRepositoryId,
        ),
        [1, 2],
      );
    },
  );

  testWidgets(
    'Import failure keeps selected rows available for explicit retry',
    (tester) async {
      final local = await _local();
      await _open(tester, local, _Source());
      local.failWrites = true;
      await _tap(tester, find.byKey(const ValueKey('github_repository_1')));
      await _tap(tester, find.byKey(const ValueKey('github_import_selected')));
      expect(find.textContaining('Не удалось сохранить'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect((await local.read())!.content!.projects, isEmpty);
      local.failWrites = false;
      await _tap(tester, find.byKey(const ValueKey('github_import_selected')));
      expect((await local.read())!.content!.projects, hasLength(1));
      expect(find.text('Уже импортирован'), findsOneWidget);
    },
  );

  testWidgets('Owner switch clears selection and late source responses', (
    tester,
  ) async {
    final first = await _local();
    final second = await _local(source: 'other');
    final source = _Source();
    final container = await _open(tester, first, source);
    await _tap(tester, find.byKey(const ValueKey('github_repository_1')));
    final delayed = Completer<GitHubRepositoriesPage>();
    source.overridePage = (profile, page) => profile.login == 'octocat'
        ? delayed.future
        : Future.value(
            GitHubRepositoriesPage(
              repositories: [_repository(2, owner: 'other')],
            ),
          );
    final refresh = container
        .read(githubImportControllerProvider.notifier)
        .refresh();
    await tester.pump();
    container.updateOverrides([
      portfolioDraftRepositoryProvider.overrideWithValue(second),
      githubImportRepositoryProvider.overrideWithValue(source),
    ]);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    delayed.complete(GitHubRepositoriesPage(repositories: [_repository(999)]));
    await refresh;
    await tester.pumpAndSettle();
    expect(find.text('@other'), findsOneWidget);
    expect(find.byKey(const ValueKey('github_repository_999')), findsNothing);
    expect(find.byKey(const ValueKey('github_repository_1')), findsNothing);
    final importButton = tester.widget<StackCardButton>(
      find.byKey(const ValueKey('github_import_selected')),
    );
    expect(importButton.onPressed, isNull);
    expect((await second.read())!.content!.projects, isEmpty);
  });

  testWidgets('Cached source remains honest and refresh errors retain rows', (
    tester,
  ) async {
    final source = _Source()..fromCache = true;
    await _open(tester, await _local(), source);
    expect(find.text('Сохранённая копия GitHub'), findsOneWidget);
    source.profileFailure = const GitHubFailure(GitHubFailureKind.network);
    await _tap(tester, find.text('Обновить GitHub'));
    expect(find.text('Нет соединения'), findsOneWidget);
    expect(find.byKey(const ValueKey('github_repository_1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bulk selection fits 320px with keyboard and scale2', (
    tester,
  ) async {
    final source = _Source()..longNames = true;
    await _open(
      tester,
      await _local(),
      source,
      size: const Size(320, 640),
      scale: 2,
    );
    await tester.enterText(
      find.byKey(const ValueKey('github_search')),
      'project',
    );
    await tester.pump(const Duration(milliseconds: 300));
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('github_repository_1'));
    await tester.scrollUntilVisible(
      row,
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('github_import_list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final checkbox = find.descendant(of: row, matching: find.byType(Checkbox));
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
    expect(
      tester
          .getBottomRight(find.byKey(const ValueKey('github_import_selected')))
          .dy,
      lessThanOrEqualTo(400),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<_Local> _local({String source = 'octocat'}) async {
  final local = _Local();
  await local.delegate.save(
    PortfolioContent(
      githubUsername: source,
      profile: const PortfolioProfile(
        username: 'existing-slug',
        bio: 'Saved biography',
      ),
    ),
    expectedRevision: 0,
    notes: 'Private saved notes',
  );
  return local;
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  _Local local,
  _Source source, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final container = ProviderContainer.test(
    overrides: [
      portfolioDraftRepositoryProvider.overrideWithValue(local),
      githubImportRepositoryProvider.overrideWithValue(source),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: StackCardTheme.light,
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const GitHubImportScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

GitHubRepository _repository(
  int id, {
  String owner = 'octocat',
  bool longName = false,
}) => GitHubRepository(
  id: id,
  name: longName ? 'project with a very long descriptive name' : 'project-$id',
  fullName: '$owner/project-$id',
  htmlUrl: 'https://github.com/$owner/project-$id',
  stars: 5,
  forks: 1,
  isFork: false,
  archived: false,
  updatedAt: DateTime.utc(2026, 10, 11),
  description: id == 2
      ? 'later repository description'
      : 'Useful project description',
  language: 'Dart',
);

class _Source implements GitHubImportRepository {
  int profileReads = 0;
  int pageReads = 0;
  bool pagination = false;
  bool fromCache = false;
  bool longNames = false;
  GitHubFailure? profileFailure;
  Future<GitHubRepositoriesPage> Function(GitHubProfile, Uri?)? overridePage;
  @override
  Future<GitHubProfile> getProfile(String username) async {
    profileReads++;
    if (profileFailure != null) throw profileFailure!;
    return GitHubProfile(
      id: 1,
      login: username,
      htmlUrl: 'https://github.com/$username',
      publicRepositories: pagination ? 2 : 1,
    );
  }

  @override
  Future<GitHubRepositoriesPage> getRepositories(
    GitHubProfile profile, {
    Uri? page,
  }) async {
    pageReads++;
    if (overridePage != null) return overridePage!(profile, page);
    return GitHubRepositoriesPage(
      repositories: [
        _repository(
          page == null ? 1 : 2,
          owner: profile.login,
          longName: longNames,
        ),
      ],
      nextPage: pagination && page == null
          ? Uri.parse(
              'https://api.github.com/users/${profile.login}/repos?page=2',
            )
          : null,
      readMetadata: GitHubReadMetadata(
        validatedAt: DateTime.utc(2026, 10, 11),
        fromCache: fromCache,
      ),
    );
  }

  @override
  void cancelRequests() {}
}

class _Local implements PortfolioDraftRepository {
  final delegate = MemoryPortfolioDraftRepository();
  bool failWrites = false;
  @override
  Future<PortfolioDraft?> read() => delegate.read();
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async {
    if (failWrites) {
      throw const PortfolioDraftFailure(PortfolioDraftFailureKind.unavailable);
    }
    return delegate.save(
      content,
      expectedRevision: expectedRevision,
      notes: notes,
    );
  }

  @override
  Future<PortfolioDraft> saveNotes(String notes) => delegate.saveNotes(notes);
}
