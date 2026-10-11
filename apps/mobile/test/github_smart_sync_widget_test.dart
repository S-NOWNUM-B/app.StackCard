import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/github_import/github_import.dart';
import 'package:app_stackcard/features/media/media.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/projects/projects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Compact Library and project editor previews', (tester) async {
    final local = await _local(_importedContent());
    await _open(tester, local);
    expect(find.byType(PortfolioMediaImage), findsNothing);
    expect(find.text('Dart'), findsNothing);
    expect(find.text('Копировать'), findsNothing);
    if (const bool.fromEnvironment('UPDATE_SINGLE_PORTFOLIO_PREVIEWS')) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('/private/tmp/stackcard-redesign-projects.png'),
      );
    }
    await _tap(tester, find.text('Редактировать'));
    if (const bool.fromEnvironment('UPDATE_SINGLE_PORTFOLIO_PREVIEWS')) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('/private/tmp/stackcard-redesign-project-editor.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Project editor retains usable fields with keyboard at 320px scale2',
    (tester) async {
      final local = await _local(_importedContent());
      await _open(tester, local, editor: true);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('builder_form_title')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('builder_form_title')),
        'Название проекта с длинным текстом',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getBottomRight(find.byKey(const ValueKey('builder_form_apply')))
            .dy,
        lessThanOrEqualTo(400),
      );
      expect(
        _text(tester, find.byKey(const ValueKey('builder_form_title'))),
        'Название проекта с длинным текстом',
      );
    },
  );

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

  testWidgets(
    'Project editor preserves GitHub overrides and legacy media while saving a stock icon',
    (tester) async {
      final local = await _local(_importedContent());
      await _open(tester, local, editor: true);
      expect(find.byType(PortfolioMediaEditor), findsNothing);
      expect(find.byType(PortfolioMediaImage), findsNothing);
      expect(find.textContaining('Обложка'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('builder_form_title')),
        'Manually edited',
      );
      await _tap(tester, find.byKey(const ValueKey('project.icon.select')));
      await _tap(tester, find.byKey(const ValueKey('project.icon.home')));
      await _tap(tester, find.byKey(const ValueKey('builder_form_apply')));
      final project = (await local.read())!.content!.projects.single;
      expect(project.source, PortfolioProjectSource.github);
      expect(project.githubRepositoryId, 42);
      expect(project.githubMetadata!.acceptedSource.name, 'Source title');
      expect(
        project.githubMetadata!.overrideFields,
        contains(PortfolioGitHubField.title),
      );
      expect(project.title, 'Manually edited');
      expect(project.iconId, 'home');
      expect(project.imagePaths, [legacyImage]);
      expect(project.lastGitHubSyncAt, _validatedAt);
      expect(local.writes, 1);
    },
  );

  testWidgets('Stale project rejects Save and retains entered text', (
    tester,
  ) async {
    final initial = _importedContent();
    final local = await _local(initial);
    final container = await _open(tester, local, editor: true);
    final changed = initial.copyWith(
      projects: [initial.projects.single.copyWith(title: 'Newer project')],
    );
    container
        .read(portfolioDraftControllerProvider.notifier)
        .updateContent(changed);
    await tester.pumpAndSettle();
    final description = find.byKey(const ValueKey('builder_form_description'));
    await tester.ensureVisible(description);
    await tester.enterText(description, 'My form input');
    await _tap(tester, find.byKey(const ValueKey('builder_form_apply')));
    expect(find.byKey(const ValueKey('builder_project_stale')), findsOneWidget);
    expect(_text(tester, description), 'My form input');
    expect(local.writes, 0);
    expect(container.read(portfolioDraftControllerProvider).content, changed);
  });

  testWidgets('Failed project Save keeps form and icon available for retry', (
    tester,
  ) async {
    final local = await _local(_importedContent());
    await _open(tester, local, editor: true);
    await tester.enterText(
      find.byKey(const ValueKey('builder_form_title')),
      'My unsaved title',
    );
    await _tap(tester, find.byKey(const ValueKey('project.icon.select')));
    await _tap(tester, find.byKey(const ValueKey('project.icon.camera')));
    local.failWrites = true;
    await _tap(tester, find.byKey(const ValueKey('builder_form_apply')));
    expect(find.byKey(const ValueKey('project.save.error')), findsOneWidget);
    expect(
      _text(tester, find.byKey(const ValueKey('builder_form_title'))),
      'My unsaved title',
    );
    expect(
      (await local.read())!.content!.projects.single.title,
      'My curated title',
    );
    local.failWrites = false;
    await _tap(tester, find.byKey(const ValueKey('builder_form_apply')));
    expect(
      (await local.read())!.content!.projects.single.title,
      'My unsaved title',
    );
    expect((await local.read())!.content!.projects.single.iconId, 'camera');
  });

  testWidgets(
    'Library deletion confirms public update and removes every relation',
    (tester) async {
      final content = _importedContent();
      final document = PortfolioDocument(
        id: 'kept-document',
        title: 'Legacy',
        kind: PortfolioDocumentKind.portfolio,
        createdAt: _validatedAt,
        updatedAt: _validatedAt,
        content: PortfolioContent(),
        projects: [
          PortfolioProjectAttachment(projectId: content.projects.single.id),
        ],
      );
      final local = await _local(content.copyWith(documents: [document]));
      await _open(tester, local);
      await _tap(tester, find.text('Удалить'));
      expect(find.textContaining('публичную версию'), findsOneWidget);
      expect((await local.read())!.content!.projects, hasLength(1));
      await _tap(tester, find.byKey(const ValueKey('project.delete.confirm')));
      final saved = (await local.read())!.content!;
      expect(saved.projects, isEmpty);
      expect(saved.documents.single.projects, isEmpty);
      expect(saved.documents.single.id, 'kept-document');
      expect(find.text('Проектов пока нет'), findsOneWidget);
    },
  );

  testWidgets(
    'Owner switch while delete confirmation is open cannot delete either owner',
    (tester) async {
      final first = await _local(_importedContent());
      final second = await _local(_importedContent());
      final container = await _open(tester, first);
      await _tap(tester, find.text('Удалить'));
      container.updateOverrides([
        portfolioDraftRepositoryProvider.overrideWithValue(second),
      ]);
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('project.delete.confirm')));
      expect((await first.read())!.content!.projects, hasLength(1));
      expect((await second.read())!.content!.projects, hasLength(1));
      expect(first.writes, 0);
      expect(second.writes, 0);
    },
  );

  testWidgets('Library query is reset for a different owner', (tester) async {
    final first = await _local(_importedContent());
    final second = await _local(_importedContent());
    final container = await _open(tester, first);
    await tester.enterText(
      find.byKey(const ValueKey('project_search')),
      'missing',
    );
    await tester.pumpAndSettle();
    expect(container.read(projectFiltersProvider).query, 'missing');
    container.updateOverrides([
      portfolioDraftRepositoryProvider.overrideWithValue(second),
    ]);
    await tester.pumpAndSettle();
    expect(container.read(projectFiltersProvider).query, '');
    expect(_text(tester, find.byKey(const ValueKey('project_search'))), '');
    expect(find.text('My curated title'), findsOneWidget);
  });
}

const legacyImage = 'accounts/owner/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg';
final _validatedAt = DateTime.utc(2026, 10, 3);
PortfolioContent _importedContent() {
  final source = GitHubRepository(
    id: 42,
    name: 'Source title',
    fullName: 'octocat/source',
    htmlUrl: 'https://github.com/octocat/source',
    description: 'GitHub description',
    language: 'Dart',
    stars: 4,
    forks: 1,
    isFork: false,
    archived: false,
    updatedAt: _validatedAt,
  );
  final content = addGitHubProject(
    PortfolioContent(),
    githubPortfolioSource(source),
    validatedAt: _validatedAt,
  );
  final original = content.projects.single;
  return content.copyWith(
    projects: [
      original
          .withUserEdits(
            original.copyWith(
              title: 'My curated title',
              iconId: 'camera',
              imagePaths: [legacyImage],
            ),
          )
          .copyWith(imagePaths: [legacyImage]),
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

Future<ProviderContainer> _open(
  WidgetTester tester,
  _Local local, {
  bool editor = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer.test(
    overrides: [portfolioDraftRepositoryProvider.overrideWithValue(local)],
  );
  final router = GoRouter(
    initialLocation: editor ? '/projects/github-42/edit' : '/projects',
    routes: [
      GoRoute(
        path: '/projects',
        builder: (_, _) => const Scaffold(body: ProjectsScreen()),
      ),
      GoRoute(
        path: '/projects/:id/edit',
        builder: (_, state) =>
            PortfolioProjectEditorScreen(projectId: state.pathParameters['id']),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: StackCardTheme.light,
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

String _text(WidgetTester tester, Finder finder) => tester
    .widget<TextFormField>(
      find.descendant(of: finder, matching: find.byType(TextFormField)),
    )
    .controller!
    .text;
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _Local implements PortfolioDraftRepository {
  final delegate = MemoryPortfolioDraftRepository();
  int writes = 0;
  bool failWrites = false;
  @override
  Future<PortfolioDraft?> read() => delegate.read();
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async {
    writes++;
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
