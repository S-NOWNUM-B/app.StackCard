import 'dart:async';

import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/github_import/github_import.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Preview is read-only and Add requires explicit durable Save', (
    tester,
  ) async {
    final source = _Source();
    final local = await _local(PortfolioContent(resumeText: 'Keep resume'));
    await _open(tester, source, local);
    final container = _container(tester);
    await _tap(tester, const ValueKey('github_preview_42'));
    expect(
      container.read(portfolioDraftControllerProvider).content!.projects,
      isEmpty,
    );
    await _tap(tester, const ValueKey('github_review_close'));
    await _tap(tester, const ValueKey('github_add_42'));
    final state = container.read(portfolioDraftControllerProvider);
    expect(state.content!.projects.single.githubRepositoryId, 42);
    expect(state.content!.resumeText, 'Keep resume');
    expect(state.notes, 'Private notes');
    expect(state.hasUnsavedChanges, isTrue);
    expect(local.writes, 0);
    expect((await local.read())!.content!.projects, isEmpty);
    await _tap(tester, const ValueKey('github_draft_save'), scrollBy: -300);
    expect(local.writes, 1);
    expect(
      (await local.read())!.content!.projects.single.githubRepositoryId,
      42,
    );
    expect(
      container.read(portfolioDraftControllerProvider).hasUnsavedChanges,
      isFalse,
    );
    expect(find.byKey(const ValueKey('github_add_42')), findsNothing);
  });

  testWidgets(
    'Ignore is tied to the source version and survives saving and reopening',
    (tester) async {
      final source = _Source();
      final local = await _local(PortfolioContent());
      await _open(tester, source, local);
      await _tap(tester, const ValueKey('github_ignore_42'));
      expect(
        _container(tester)
            .read(portfolioDraftControllerProvider)
            .content!
            .ignoredGitHubRepositories
            .single
            .repositoryId,
        42,
      );
      await _tap(tester, const ValueKey('github_draft_save'), scrollBy: -300);
      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, source, local);
      await _visible(tester, find.byKey(const ValueKey('github_status_42')));
      expect(find.text('Пропущен'), findsOneWidget);
      source.repository = _repository(description: 'Changed later');
      await _container(tester)
          .read(githubImportControllerProvider.notifier)
          .refresh();
      await tester.pumpAndSettle();
      expect(find.text('Новый для портфолио'), findsOneWidget);
      expect(find.byKey(const ValueKey('github_ignore_42')), findsOneWidget);
      expect((await local.read())!.content!.projects, isEmpty);
    },
  );

  testWidgets(
    'Review Cancel does not mutate; Accept keeps manual overrides and private content',
    (tester) async {
      final initial = _importedContent();
      final source = _Source()
        ..repository = _repository(
          description: 'New GitHub description',
          name: 'New GitHub title',
        );
      final local = await _local(initial);
      await _open(tester, source, local);
      final container = _container(tester);
      await _tap(tester, const ValueKey('github_review_42'));
      expect(find.text('Твоё значение сохранится'), findsOneWidget);
      expect(find.text('My curated title'), findsOneWidget);
      await _tap(tester, const ValueKey('github_review_close'));
      expect(container.read(portfolioDraftControllerProvider).content, initial);
      await _tap(tester, const ValueKey('github_review_42'));
      await _tap(tester, const ValueKey('github_review_accept'));
      final content = container.read(portfolioDraftControllerProvider).content!;
      expect(content.projects.single.title, 'My curated title');
      expect(content.projects.single.description, 'New GitHub description');
      expect(content.projects.single.featured, isTrue);
      expect(content.projects.single.liveUrl, 'https://example.com/demo');
      expect(content.resumeText, 'Keep resume');
      expect(
        container.read(portfolioDraftControllerProvider).notes,
        'Private notes',
      );
      expect(local.writes, 0);
    },
  );

  testWidgets(
    'Metadata-only review exposes accepted and incoming activity before accepting',
    (tester) async {
      final source = _Source()
        ..repository = _repository(stars: 9, forks: 3, archived: true);
      final local = await _local(_importedContent());
      await _open(tester, source, local);
      final container = _container(tester);
      await _tap(tester, const ValueKey('github_review_42'));
      final stars = find.byKey(const ValueKey('github_metadata_stars'));
      expect(
        find.descendant(of: stars, matching: find.text('4')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: stars, matching: find.text('9')),
        findsOneWidget,
      );
      final forks = find.byKey(const ValueKey('github_metadata_forks'));
      expect(
        find.descendant(of: forks, matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: forks, matching: find.text('3')),
        findsOneWidget,
      );
      final archived = find.byKey(const ValueKey('github_metadata_archived'));
      expect(
        find.descendant(of: archived, matching: find.text('Нет')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: archived, matching: find.text('Да')),
        findsOneWidget,
      );
      await _tap(tester, const ValueKey('github_review_accept'));
      final project = container
          .read(portfolioDraftControllerProvider)
          .content!
          .projects
          .single;
      expect(project.githubMetadata!.acceptedSource.stars, 9);
      expect(project.title, 'My curated title');
      expect(local.writes, 0);
    },
  );

  testWidgets(
    'An ignored imported version can be reviewed again and accepted',
    (tester) async {
      final source = _Source()
        ..repository = _repository(description: 'Ignored update');
      final local = await _local(_importedContent());
      await _open(tester, source, local);
      final container = _container(tester);
      await _tap(tester, const ValueKey('github_ignore_42'));
      expect(find.text('Пропущен'), findsOneWidget);
      await _tap(tester, const ValueKey('github_review_42'));
      await _tap(tester, const ValueKey('github_review_accept'));
      final content = container.read(portfolioDraftControllerProvider).content!;
      expect(content.projects.single.description, 'Ignored update');
      expect(content.ignoredGitHubRepositories, isEmpty);
      expect(local.writes, 0);
    },
  );

  testWidgets(
    'A source refresh while the review is open rejects the stale acceptance',
    (tester) async {
      final source = _Source()
        ..repository = _repository(description: 'First change');
      final initial = _importedContent();
      final local = await _local(initial);
      await _open(tester, source, local);
      final container = _container(tester);
      await _tap(tester, const ValueKey('github_review_42'));
      source.repository = _repository(description: 'Second change');
      await container.read(githubImportControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();
      await _tap(tester, const ValueKey('github_review_accept'));
      expect(container.read(portfolioDraftControllerProvider).content, initial);
      expect(local.writes, 0);
      expect(find.textContaining('источник изменился'), findsOneWidget);
    },
  );

  testWidgets(
    'Editing an imported Project records overrides without losing source metadata',
    (tester) async {
      final local = await _local(_importedContent());
      await _open(tester, _Source(), local);
      final container = _container(tester);
      await _tap(tester, const ValueKey('github_edit_42'));
      final title = find.byKey(const ValueKey('builder_form_title'));
      await tester.enterText(title, 'Manually edited');
      await _tap(tester, const ValueKey('builder_form_apply'));
      final project = container
          .read(portfolioDraftControllerProvider)
          .content!
          .projects
          .single;
      expect(project.source, PortfolioProjectSource.github);
      expect(project.githubRepositoryId, 42);
      expect(project.githubMetadata!.acceptedSource.name, 'Source title');
      expect(
        project.githubMetadata!.overrideFields,
        contains(PortfolioGitHubField.title),
      );
      expect(project.title, 'Manually edited');
      expect(project.lastGitHubSyncAt, _validatedAt);
      expect(local.writes, 0);
    },
  );

  testWidgets(
    'Project changes while editing reject Apply and keep the entered text',
    (tester) async {
      final local = await _local(_importedContent());
      await _open(tester, _Source(), local);
      final container = _container(tester);
      await _tap(tester, const ValueKey('github_edit_42'));
      final original = container
          .read(portfolioDraftControllerProvider)
          .content!;
      final changed = original.copyWith(
        projects: [
          original.projects.single.copyWith(title: 'New durable title'),
        ],
      );
      container
          .read(portfolioDraftControllerProvider.notifier)
          .updateContent(changed);
      await tester.pumpAndSettle();
      final description = find.byKey(
        const ValueKey('builder_form_description'),
      );
      await _visible(tester, description);
      await tester.enterText(description, 'My form input');
      await _tap(tester, const ValueKey('builder_form_apply'));
      expect(container.read(portfolioDraftControllerProvider).content, changed);
      expect(
        find.byKey(const ValueKey('builder_project_stale')),
        findsOneWidget,
      );
      final field = tester.widget<TextFormField>(
        find.descendant(of: description, matching: find.byType(TextFormField)),
      );
      expect(field.controller!.text, 'My form input');
      expect(local.writes, 0);
    },
  );

  for (final invalid in [
    ('empty language', _repository(language: '')),
    ('blank full name', _repository(fullName: ' ')),
    (
      'oversized description',
      _repository(description: List.filled(4001, 'x').join()),
    ),
  ]) {
    testWidgets(
      'Invalid public source ${invalid.$1} keeps the card readable without import actions',
      (tester) async {
        final source = _Source()..repository = invalid.$2;
        final local = _Local();
        final auth = _Auth();
        addTearDown(auth.close);
        await _open(tester, source, local, auth: auth);
        await _visible(tester, find.byKey(const ValueKey('github_invalid_42')));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('github_add_42')), findsNothing);
        expect(find.byKey(const ValueKey('github_ignore_42')), findsNothing);
        expect(local.reads, 0);
        expect(local.writes, 0);
      },
    );
  }

  testWidgets(
    'Public browsing opens no private draft and offers only Preview and sign-in',
    (tester) async {
      final local = _Local();
      final auth = _Auth();
      addTearDown(auth.close);
      await _open(tester, _Source(), local, auth: auth);
      await _visible(tester, find.byKey(const ValueKey('github_preview_42')));
      expect(local.reads, 0);
      expect(find.byKey(const ValueKey('github_add_42')), findsNothing);
      expect(find.text('Войти для импорта'), findsOneWidget);
      await _tap(tester, const ValueKey('github_preview_42'));
      await _tap(tester, const ValueKey('github_review_close'));
      expect(local.reads, 0);
      expect(local.writes, 0);
    },
  );

  for (final theme in [AppTheme.dark, AppTheme.light]) {
    for (final language in [AppLanguage.ru, AppLanguage.en]) {
      testWidgets(
        'Review supports $theme $language at 320px with enlarged text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final source = _Source()
            ..repository = _repository(
              description:
                  'A changed description with enough text to check wrapping.',
            );
          final local = await _local(_importedContent());
          await _open(
            tester,
            source,
            local,
            settings: AppSettings(theme: theme, language: language),
          );
          await _tap(tester, const ValueKey('github_review_42'));
          await _visible(
            tester,
            find.byKey(const ValueKey('github_review_accept')),
          );
          expect(tester.takeException(), isNull);
          await _tap(tester, const ValueKey('github_review_close'));
          expect(local.writes, 0);
        },
      );
    }
  }
}

final _validatedAt = DateTime.utc(2026, 10, 3);

PortfolioContent _importedContent() {
  final content = addGitHubProject(
    PortfolioContent(resumeText: 'Keep resume'),
    githubPortfolioSource(_repository()),
    validatedAt: _validatedAt,
  );
  final original = content.projects.single;
  final edited = original.withUserEdits(
    original.copyWith(
      title: 'My curated title',
      featured: true,
      liveUrl: 'https://example.com/demo',
    ),
  );
  return content.copyWith(projects: [edited]);
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

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GitHubImportScreen)));

Future<void> _open(
  WidgetTester tester,
  _Source source,
  _Local local, {
  _Auth? auth,
  AppSettings? settings,
}) async {
  await tester.pumpWidget(
    StackCardApp(
      initialLocation: '/github-import',
      initialSettings: settings,
      providerOverrides: [
        githubImportRepositoryProvider.overrideWithValue(source),
        portfolioDraftRepositoryProvider.overrideWithValue(local),
        if (auth != null) accountAuthRepositoryProvider.overrideWithValue(auth),
      ],
    ),
  );
  await tester.pumpAndSettle();
  await _container(tester)
      .read(githubImportControllerProvider.notifier)
      .load('octocat');
  await tester.pumpAndSettle();
}

Future<void> _visible(
  WidgetTester tester,
  Finder finder, {
  double scrollBy = 300,
}) async {
  await tester.pumpAndSettle();
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      scrollBy,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key, {double scrollBy = 300}) async {
  final finder = find.byKey(key);
  await _visible(tester, finder, scrollBy: scrollBy);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

GitHubRepository _repository({
  String name = 'Source title',
  String description = 'Old GitHub description',
  int stars = 4,
  int forks = 1,
  bool archived = false,
  String fullName = 'octocat/source',
  String? language = 'Dart',
}) => GitHubRepository(
  id: 42,
  name: name,
  fullName: fullName,
  htmlUrl: 'https://github.com/octocat/source',
  stars: stars,
  forks: forks,
  isFork: false,
  archived: archived,
  updatedAt: DateTime.utc(2026, 10, 3),
  description: description,
  language: language,
);

class _Source implements GitHubImportRepository {
  GitHubRepository repository = _repository();
  @override
  Future<GitHubProfile> getProfile(String username) async => GitHubProfile(
    id: 1,
    login: 'octocat',
    htmlUrl: 'https://github.com/octocat',
    publicRepositories: 1,
    readMetadata: GitHubReadMetadata(validatedAt: _validatedAt),
  );
  @override
  Future<GitHubRepositoriesPage> getRepositories(
    GitHubProfile profile, {
    Uri? page,
  }) async => GitHubRepositoriesPage(
    repositories: [repository],
    readMetadata: GitHubReadMetadata(validatedAt: _validatedAt),
  );
  @override
  void cancelRequests() {}
}

class _Local implements PortfolioDraftRepository {
  final delegate = MemoryPortfolioDraftRepository();
  int reads = 0;
  int writes = 0;
  @override
  Future<PortfolioDraft?> read() {
    reads++;
    return delegate.read();
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

class _Auth implements AccountAuthRepository {
  final sessions = StreamController<AuthUser?>.broadcast();
  Future<void> close() => sessions.close();
  @override
  Stream<AuthUser?> watchSession() => Stream.multi((controller) {
    controller.add(null);
    final subscription = sessions.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
  });
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
