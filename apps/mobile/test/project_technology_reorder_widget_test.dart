import 'dart:io';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/github_import/github_import.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/builder_tag_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

PortfolioContent _content() {
  final source = GitHubRepository(
    id: 42,
    name: 'Source',
    fullName: 'octocat/source',
    htmlUrl: 'https://github.com/octocat/source',
    description: 'Source description',
    language: 'Dart',
    stars: 1,
    forks: 0,
    isFork: false,
    archived: false,
    updatedAt: DateTime.utc(2026, 10, 12),
  );
  final content = addGitHubProject(
    PortfolioContent(),
    githubPortfolioSource(source),
  );
  return content.copyWith(
    projects: [
      content.projects.single.copyWith(
        technologies: ['Dart', 'React', 'Team, tools'],
      ),
    ],
  );
}

Future<({ProviderContainer container, GoRouter router})> _open(
  WidgetTester tester,
  PortfolioDraftRepository repository, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer.test(
    overrides: [portfolioDraftRepositoryProvider.overrideWithValue(repository)],
  );
  final router = GoRouter(
    initialLocation: '/projects/github-42/edit',
    routes: [
      GoRoute(
        path: '/projects',
        builder: (_, _) => const Scaffold(body: Text('Library')),
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container: container, router: router);
}

Future<void> _dragFirstToLast(WidgetTester tester) async {
  final first = find.byKey(const ValueKey('project.technology.drag.0'));
  await Scrollable.ensureVisible(
    tester.element(
      find.byKey(
        const ValueKey('project.technologies.editor'),
        skipOffstage: false,
      ),
    ),
    alignment: 0,
  );
  await tester.pumpAndSettle();
  final last = find.byKey(const ValueKey('project.technology.drag.2'));
  final origin = tester.getCenter(first);
  final target = tester.getCenter(last) + const Offset(0, 60);
  final gesture = await tester.startGesture(origin);
  await tester.pump(const Duration(milliseconds: 650));
  await gesture.moveTo(target);
  await tester.pump(const Duration(milliseconds: 400));
  await gesture.up();
  await tester.pumpAndSettle();
}

List<String> _technologyOrder(WidgetTester tester) => tester
    .widget<BuilderTagsEditor>(
      find.byKey(
        const ValueKey('project.technologies.editor'),
        skipOffstage: false,
      ),
    )
    .items;

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('builder_form_apply')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('UPDATE_SINGLE_PORTFOLIO_PREVIEWS')) return;
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
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  test(
    'Scoped technology Save survives actual Hive close and reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'stackcard-technology-order-',
      );
      var box = await Hive.openBox<dynamic>(
        'technologies',
        path: directory.path,
      );
      addTearDown(() async {
        await box.close();
        await directory.delete(recursive: true);
      });
      final repository = HivePortfolioDraftRepository(box);
      final initial = _content();
      await repository.save(
        initial,
        expectedRevision: 0,
        notes: 'Private notes',
      );
      final container = ProviderContainer.test(
        overrides: [
          portfolioDraftRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      await controller.ensureLoaded();
      final original = initial.projects.single;
      final edited = original.withUserEdits(
        original.copyWith(technologies: ['React', 'Team, tools', 'Dart']),
      );
      expect(
        await controller.saveProject(
          edited,
          expectedProject: original,
          expectedRepository: repository,
        ),
        isTrue,
      );
      container.dispose();
      await box.close();
      box = await Hive.openBox<dynamic>('technologies', path: directory.path);
      final reopened = (await HivePortfolioDraftRepository(box).read())!;
      expect(reopened.content!.projects.single, edited);
      expect(reopened.content!.projects.single.technologies, [
        'React',
        'Team, tools',
        'Dart',
      ]);
      expect(reopened.notes, 'Private notes');
    },
  );

  testWidgets(
    'Real delayed drag stays local until Save; reopen preserves order and metadata',
    (tester) async {
      final repository = _Repository();
      final initial = _content();
      await repository.delegate.save(
        initial,
        expectedRevision: 0,
        notes: 'Saved notes',
      );
      final scope = await _open(tester, repository);
      final controller = scope.container.read(
        portfolioDraftControllerProvider.notifier,
      );
      controller.updateContent(
        initial.copyWith(profile: const PortfolioProfile(name: 'Unsaved name')),
      );
      controller.updateNotes('Unsaved notes');
      await tester.pumpAndSettle();
      await _dragFirstToLast(tester);
      expect(_technologyOrder(tester), ['React', 'Team, tools', 'Dart']);
      expect(repository.writes, 0);
      expect(
        (await repository.read())!.content!.projects.single.technologies,
        initial.projects.single.technologies,
      );
      await _save(tester);
      final saved = (await repository.read())!;
      expect(saved.content!.projects.single.technologies, [
        'React',
        'Team, tools',
        'Dart',
      ]);
      expect(saved.content!.projects.single.id, initial.projects.single.id);
      expect(
        saved.content!.projects.single.githubMetadata!.acceptedSource,
        initial.projects.single.githubMetadata!.acceptedSource,
      );
      expect(
        saved.content!.projects.single.githubMetadata!.overrideFields,
        contains(PortfolioGitHubField.technologies),
      );
      expect(saved.content!.profile, initial.profile);
      expect(saved.notes, 'Saved notes');
      expect(controller.workingContent!.profile.name, 'Unsaved name');
      expect(
        scope.container.read(portfolioDraftControllerProvider).notes,
        'Unsaved notes',
      );
      scope.router.go('/projects/github-42/edit');
      await tester.pumpAndSettle();
      expect(_technologyOrder(tester), ['React', 'Team, tools', 'Dart']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Failed Save retains reordered buffer and retry persists it', (
    tester,
  ) async {
    final repository = _Repository();
    await repository.delegate.save(
      _content(),
      expectedRevision: 0,
      notes: 'Saved notes',
    );
    await _open(tester, repository);
    await _dragFirstToLast(tester);
    repository.failWrites = true;
    await _save(tester);
    expect(find.byKey(const ValueKey('project.save.error')), findsOneWidget);
    expect(_technologyOrder(tester), ['React', 'Team, tools', 'Dart']);
    expect((await repository.read())!.content!.projects.single.technologies, [
      'Dart',
      'React',
      'Team, tools',
    ]);
    repository.failWrites = false;
    await _save(tester);
    expect((await repository.read())!.content!.projects.single.technologies, [
      'React',
      'Team, tools',
      'Dart',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Captured technology callback cannot mutate a different owner', (
    tester,
  ) async {
    final repository = _Repository();
    await repository.delegate.save(_content(), expectedRevision: 0, notes: '');
    final scope = await _open(tester, repository);
    final callback = tester
        .widget<BuilderTagsEditor>(find.byType(BuilderTagsEditor))
        .onReorder!;
    final second = _Repository();
    await second.delegate.save(
      _content(),
      expectedRevision: 0,
      notes: 'Other owner',
    );
    scope.container.updateOverrides([
      portfolioDraftRepositoryProvider.overrideWithValue(second),
    ]);
    await tester.pumpAndSettle();
    callback(0, 2);
    await tester.pumpAndSettle();
    expect(repository.writes, 0);
    expect(second.writes, 0);
    expect(
      find.byKey(const ValueKey('project.technology.drag.0')),
      findsNothing,
    );
    expect((await second.read())!.content!.projects.single.technologies, [
      'Dart',
      'React',
      'Team, tools',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Long technology drag autoscroll reaches the final row', (
    tester,
  ) async {
    final repository = _Repository();
    final initial = _content();
    final technologies = [for (var i = 0; i < 20; i++) 'Tech$i'];
    await repository.delegate.save(
      initial.copyWith(
        projects: [
          initial.projects.single.copyWith(technologies: technologies),
        ],
      ),
      expectedRevision: 0,
      notes: '',
    );
    await _open(tester, repository);
    await Scrollable.ensureVisible(
      tester.element(
        find.byKey(
          const ValueKey('project.technologies.editor'),
          skipOffstage: false,
        ),
      ),
      alignment: 0,
    );
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final before = scrollable.position.pixels;
    final viewport = tester.getRect(
      find.byKey(const Key('project.editor.scroll')),
    );
    final first = find.byKey(const ValueKey('project.technology.drag.0'));
    final gesture = await tester.startGesture(tester.getCenter(first));
    await tester.pump(const Duration(milliseconds: 650));
    final edge = Offset(tester.getCenter(first).dx, viewport.bottom - 8);
    await gesture.moveTo(edge);
    final last = find.byKey(const ValueKey('project.technology.drag.19'));
    for (var i = 0; i < 600; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (last.evaluate().isNotEmpty &&
          tester.getRect(last).bottom < viewport.bottom - 60) {
        break;
      }
    }
    expect(last, findsOneWidget);
    await gesture.moveTo(tester.getCenter(last) + const Offset(0, 50));
    await tester.pump(const Duration(milliseconds: 300));
    final after = scrollable.position.pixels;
    await gesture.up();
    await tester.pumpAndSettle();
    expect(after, greaterThan(before));
    expect(_technologyOrder(tester).last, 'Tech0');
  });

  testWidgets('Technology rows and drag targets fit width320 text2', (
    tester,
  ) async {
    final repository = _Repository();
    final initial = _content();
    await repository.delegate.save(
      initial.copyWith(
        projects: [
          initial.projects.single.copyWith(
            technologies: [
              'Technology with a long display name',
              'React',
              'Dart',
            ],
          ),
        ],
      ),
      expectedRevision: 0,
      notes: '',
    );
    await _open(tester, repository, width: 320, scale: 2);

    final first = find.byKey(const ValueKey('project.technology.drag.0'));
    await Scrollable.ensureVisible(
      tester.element(
        find.byKey(
          const ValueKey('project.technologies.editor'),
          skipOffstage: false,
        ),
      ),
      alignment: 0,
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(first), const Size(48, 48));
    for (var i = 0; i < 3; i++) {
      final remove = find.byKey(ValueKey('project.technology.remove.$i'));
      final rect = tester.getRect(remove);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
    if (const bool.fromEnvironment('UPDATE_SINGLE_PORTFOLIO_PREVIEWS')) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '/private/tmp/stackcard-project-technologies-narrow.png',
        ),
      );
    }
    expect(tester.takeException(), isNull);
  });
}

class _Repository implements PortfolioDraftRepository {
  final delegate = MemoryPortfolioDraftRepository();
  bool failWrites = false;
  int writes = 0;
  @override
  Future<PortfolioDraft?> read() => delegate.read();
  @override
  Future<PortfolioDraft> saveNotes(String notes) => delegate.saveNotes(notes);
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
}
