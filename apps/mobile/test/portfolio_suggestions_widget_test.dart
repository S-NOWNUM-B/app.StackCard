import 'dart:async';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/github_import/github_import.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/projects/projects.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets(
    'Manual advice opens its editor without changing or saving a draft',
    (tester) async {
      final content = _manualContent();
      final local = await _local(content);
      await _openProjects(tester, local);
      final container = _container(tester, ProjectsScreen);
      expect(find.textContaining('Без описания'), findsOneWidget);
      expect(find.textContaining('нет демо-ссылки'), findsOneWidget);
      expect(find.text('Добавить описание'), findsOneWidget);
      expect(find.text('Добавить демо-ссылку'), findsOneWidget);
      expect(container.read(portfolioDraftControllerProvider).content, content);
      expect(local.writes, 0);
      await _tap(tester, find.text('Добавить демо-ссылку'));
      expect(
        tester
            .widget<PortfolioProjectEditorScreen>(
              find.byType(PortfolioProjectEditorScreen),
            )
            .projectId,
        'manual-1',
      );
      expect(
        find.byKey(const ValueKey('builder_form_liveUrl')),
        findsOneWidget,
      );
      expect(container.read(portfolioDraftControllerProvider).content, content);
      expect(local.writes, 0);
      expect((await local.read())!.content, content);
    },
  );

  testWidgets(
    'New source advice reuses Preview and leaves import, Save and publication explicit',
    (tester) async {
      final content = PortfolioContent();
      final local = await _local(content);
      await _openGitHub(tester, local, _repository());
      final container = _container(tester, GitHubImportScreen);
      await _visible(
        tester,
        find.byKey(const ValueKey('github_suggestions_42')),
      );
      expect(
        find.textContaining('ещё не добавлен в портфолио'),
        findsOneWidget,
      );
      expect(find.textContaining('Открой «Предпросмотр»'), findsOneWidget);
      expect(find.byKey(const ValueKey('github_preview_42')), findsOneWidget);
      expect(find.text('Предпросмотр источника'), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('github_preview_42')));
      expect(find.textContaining('Портфолио не меняется'), findsOneWidget);
      expect(container.read(portfolioDraftControllerProvider).content, content);
      expect(local.writes, 0);
      expect(
        container.read(portfolioDraftControllerProvider).hasUnsavedChanges,
        isFalse,
      );
      expect((await local.read())!.revision, 1);
    },
  );

  testWidgets(
    'Current repository update advice keeps curated description and featured choice',
    (tester) async {
      final source = _repository(description: '');
      final content = _importedContent(
        source,
        description: '',
        featured: false,
      );
      final local = await _local(content);
      await _openGitHub(
        tester,
        local,
        _repository(description: 'Incoming public description'),
      );
      final container = _container(tester, GitHubImportScreen);
      await _visible(
        tester,
        find.byKey(const ValueKey('github_suggestions_42')),
      );
      expect(
        find.textContaining('Репозиторий обновлён 2026-10-03'),
        findsOneWidget,
      );
      expect(find.textContaining('Без описания'), findsOneWidget);
      expect(find.textContaining('нет демо-ссылки'), findsOneWidget);
      expect(
        find.textContaining('Открой «Редактировать проект»'),
        findsOneWidget,
      );
      expect(container.read(portfolioDraftControllerProvider).content, content);
      expect(
        container
            .read(portfolioDraftControllerProvider)
            .content!
            .projects
            .single
            .featured,
        isFalse,
      );
      expect(local.writes, 0);
    },
  );

  testWidgets(
    'Inactive and starred candidate explain accepted source without auto featuring',
    (tester) async {
      final repository = _repository(
        updatedAt: DateTime.utc(2025, 1, 1),
        stars: 8,
      );
      final content = _importedContent(
        repository,
        liveUrl: 'https://example.com/demo',
      );
      final local = await _local(content);
      await _openProjects(tester, local);
      expect(find.textContaining('не менее 180 дней назад'), findsOneWidget);
      expect(find.textContaining('У репозитория 8 звёзд'), findsOneWidget);
      expect(find.text('Проверить актуальность'), findsOneWidget);
      expect(find.text('Проверить Featured'), findsOneWidget);
      expect(
        _container(
          tester,
          ProjectsScreen,
        ).read(portfolioDraftControllerProvider).content,
        content,
      );
      expect(local.writes, 0);
    },
  );

  testWidgets(
    'Manual featured candidate explains complete curated fields and demo',
    (tester) async {
      final content = _manualContent(
        description: 'Useful project',
        liveUrl: 'https://example.com/demo',
      );
      final local = await _local(content);
      await _openProjects(tester, local);
      expect(
        find.textContaining('Есть описание, технологии и демо-ссылка'),
        findsOneWidget,
      );
      expect(find.text('Проверить Featured'), findsOneWidget);
      expect(find.textContaining('звёзд'), findsNothing);
      expect(local.writes, 0);
      expect(
        _container(tester, ProjectsScreen)
            .read(portfolioDraftControllerProvider)
            .content!
            .projects
            .single
            .featured,
        isFalse,
      );
    },
  );

  testWidgets('English advice names a demo URL and localized editor actions', (
    tester,
  ) async {
    await _openProjects(
      tester,
      await _local(_manualContent()),
      language: AppLanguage.en,
    );
    expect(find.text('Ideas for your portfolio'), findsOneWidget);
    expect(find.textContaining('no demo URL'), findsOneWidget);
    expect(find.text('Add description'), findsOneWidget);
    expect(find.text('Add demo URL'), findsOneWidget);
    expect(find.textContaining('suggestions.'), findsNothing);
  });

  testWidgets('English source advice points to the existing Preview', (
    tester,
  ) async {
    await _openGitHub(
      tester,
      await _local(PortfolioContent()),
      _repository(),
      language: AppLanguage.en,
    );
    await _visible(tester, find.byKey(const ValueKey('github_suggestions_42')));
    expect(
      find.textContaining('has not been added to your portfolio'),
      findsOneWidget,
    );
    expect(find.text('Open Preview to check the source.'), findsOneWidget);
    expect(find.byKey(const ValueKey('github_preview_42')), findsOneWidget);
  });

  testWidgets(
    'Demo content and an empty curated portfolio have no advice panel',
    (tester) async {
      await _openProjects(tester, _Local());
      expect(find.byKey(const ValueKey('projects_suggestions')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await _openProjects(tester, await _local(PortfolioContent()));
      expect(find.byKey(const ValueKey('projects_suggestions')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Loading and corrupted draft never expose private suggestions', (
    tester,
  ) async {
    final pending = Completer<PortfolioDraft?>();
    final local = _Local()..readResult = () => pending.future;
    await tester.pumpWidget(
      StackCardApp(
        initialLocation: '/projects',
        providerOverrides: [
          portfolioDraftRepositoryProvider.overrideWithValue(local),
        ],
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('projects_suggestions')), findsNothing);
    pending.completeError(
      const PortfolioDraftFailure(PortfolioDraftFailureKind.corrupted),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('projects_suggestions')), findsNothing);
    expect(local.writes, 0);
  });

  testWidgets(
    'Public GitHub browsing does not open private data or offer suggestions',
    (tester) async {
      final local = _Local();
      final auth = _SignedOutAuth();
      await _openGitHub(tester, local, _repository(), auth: auth);
      await _visible(tester, find.byKey(const ValueKey('github_preview_42')));
      expect(find.byKey(const ValueKey('github_suggestions_42')), findsNothing);
      expect(local.reads, 0);
      expect(local.writes, 0);
    },
  );

  for (final size in [const Size(320, 740), const Size(900, 1000)]) {
    testWidgets('Advice remains readable at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      final suggestions = buildPortfolioSuggestions(
        content: _manualContent(),
        now: _now,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: StackCardTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: const [AppStrings.delegate],
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(2),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: PortfolioSuggestionList(
                    suggestions: suggestions,
                    onAction: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('no demo URL'), findsOneWidget);
      await _visible(tester, find.text('Add demo URL'));
      expect(tester.takeException(), isNull);
    });
  }
}

final _now = DateTime.utc(2026, 10, 4);

PortfolioContent _manualContent({
  String description = '',
  String liveUrl = '',
}) => PortfolioContent(
  projects: [
    PortfolioProject(
      id: 'manual-1',
      title: 'Manual project',
      description: description,
      technologies: const ['Dart'],
      liveUrl: liveUrl,
    ),
  ],
);

GitHubRepository _repository({
  String description = 'Public description',
  DateTime? updatedAt,
  int stars = 5,
}) => GitHubRepository(
  id: 42,
  name: 'Public source',
  fullName: 'octocat/source',
  htmlUrl: 'https://github.com/octocat/source',
  description: description,
  language: 'Dart',
  stars: stars,
  forks: 0,
  isFork: false,
  archived: false,
  updatedAt: updatedAt ?? DateTime.utc(2026, 10, 3),
);

PortfolioContent _importedContent(
  GitHubRepository repository, {
  String? description,
  String liveUrl = '',
  bool featured = false,
}) {
  final content = addGitHubProject(
    PortfolioContent(),
    githubPortfolioSource(repository),
    validatedAt: _now,
  );
  final original = content.projects.single;
  return content.copyWith(
    projects: [
      original.withUserEdits(
        original.copyWith(
          description: description,
          liveUrl: liveUrl,
          featured: featured,
        ),
      ),
    ],
  );
}

Future<_Local> _local(PortfolioContent content) async {
  final local = _Local();
  await local.delegate.save(
    content,
    expectedRevision: 0,
    notes: 'Private notes',
  );
  return local;
}

Future<void> _openProjects(
  WidgetTester tester,
  _Local local, {
  AppLanguage language = AppLanguage.ru,
}) async {
  await tester.pumpWidget(
    StackCardApp(
      initialLocation: '/projects',
      initialSettings: AppSettings(language: language),
      providerOverrides: [
        portfolioDraftRepositoryProvider.overrideWithValue(local),
        portfolioSuggestionClockProvider.overrideWithValue(() => _now),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openGitHub(
  WidgetTester tester,
  _Local local,
  GitHubRepository repository, {
  AppLanguage language = AppLanguage.ru,
  AccountAuthRepository? auth,
}) async {
  await tester.pumpWidget(
    StackCardApp(
      initialLocation: '/github-import',
      initialSettings: AppSettings(language: language),
      providerOverrides: [
        portfolioDraftRepositoryProvider.overrideWithValue(local),
        portfolioSuggestionClockProvider.overrideWithValue(() => _now),
        githubImportRepositoryProvider.overrideWithValue(_Source(repository)),
        if (auth != null) accountAuthRepositoryProvider.overrideWithValue(auth),
      ],
    ),
  );
  await tester.pumpAndSettle();
  await _container(
    tester,
    GitHubImportScreen,
  ).read(githubImportControllerProvider.notifier).load('octocat');
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester, Type type) =>
    ProviderScope.containerOf(tester.element(find.byType(type)));

Future<void> _visible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _visible(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _Local implements PortfolioDraftRepository {
  final delegate = MemoryPortfolioDraftRepository();
  Future<PortfolioDraft?> Function()? readResult;
  int reads = 0;
  int writes = 0;

  @override
  Future<PortfolioDraft?> read() {
    reads++;
    return readResult?.call() ?? delegate.read();
  }

  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) {
    writes++;
    return delegate.save(
      content,
      expectedRevision: expectedRevision,
      notes: notes,
    );
  }

  @override
  Future<PortfolioDraft> saveNotes(String notes) {
    writes++;
    return delegate.saveNotes(notes);
  }
}

class _Source implements GitHubImportRepository {
  const _Source(this.repository);
  final GitHubRepository repository;
  @override
  Future<GitHubProfile> getProfile(String username) async => GitHubProfile(
    id: 1,
    login: 'octocat',
    htmlUrl: 'https://github.com/octocat',
    publicRepositories: 1,
  );
  @override
  Future<GitHubRepositoriesPage> getRepositories(
    GitHubProfile profile, {
    Uri? page,
  }) async => GitHubRepositoriesPage(repositories: [repository]);
  @override
  void cancelRequests() {}
}

class _SignedOutAuth implements AccountAuthRepository {
  @override
  Stream<AuthUser?> watchSession() => Stream.value(null);
  @override
  Future<void> signOut() async {}
  @override
  Future<void> signInEmail(String email, String password) async {}
  @override
  Future<void> registerEmail(String email, String password) async {}
  @override
  Future<void> signInGoogle() async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
}
