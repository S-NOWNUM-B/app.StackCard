import 'dart:async';

import 'package:app_stackcard/features/github_import/github_import.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'HTTP source keeps its rate deadline when the screen is reopened',
    () async {
      final container = ProviderContainer.test();
      final firstScreen = container.listen(
        githubImportControllerProvider,
        (_, _) {},
      );
      final repository = container.read(githubImportRepositoryProvider);
      firstScreen.close();
      await container.pump();
      final nextScreen = container.listen(
        githubImportControllerProvider,
        (_, _) {},
      );
      expect(container.read(githubImportRepositoryProvider), same(repository));
      expect(container.read(githubImportControllerProvider).profile, isNull);
      nextScreen.close();
    },
  );

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
    'Import is reachable from Projects, validates input and keeps portfolio sources separate',
    (tester) async {
      final source = _Source();
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/projects',
          providerOverrides: [
            githubImportRepositoryProvider.overrideWithValue(source),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('GitHub Import'));
      await tester.pumpAndSettle();
      expect(source.profileReads, 0);
      await tester.tap(find.text('Загрузить профиль'));
      await tester.pumpAndSettle();
      expect(find.text('Введи username GitHub'), findsOneWidget);
      expect(source.profileReads, 0);
      await tester.enterText(
        find.byKey(const ValueKey('github_username')),
        ' octocat ',
      );
      await tester.tap(find.text('Загрузить профиль'));
      await tester.pumpAndSettle();
      expect(find.text('@octocat'), findsOneWidget);
      expect(source.profileReads, 1);
      await tester.tap(find.byTooltip('Назад к проектам'));
      await tester.pumpAndSettle();
      expect(find.text('Atlas UI Kit'), findsOneWidget);
      expect(find.text('Source repository'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pending, failure and retry are visible without leaking exception data',
    (tester) async {
      final source = _Source();
      final pending = Completer<GitHubProfile>();
      source.readProfile = () => pending.future;
      await _open(tester, source);
      await _submit(tester);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Загрузка GitHub'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Загрузка GitHub'), findsOneWidget);
      pending.completeError(const GitHubFailure(GitHubFailureKind.timeout));
      await tester.pumpAndSettle();
      expect(find.text('GitHub не ответил вовремя'), findsOneWidget);
      source.readProfile = () async => _profile;
      await tester.ensureVisible(find.text('Повторить'));
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('@octocat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Loaded search debounces, pages append and refresh preserves a failed snapshot',
    (tester) async {
      final source = _Source();
      await _open(tester, source);
      await _submit(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('github_search')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('github_search')),
        'missing',
      );
      await tester.pump(const Duration(milliseconds: 299));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GitHubImportScreen)),
      );
      expect(container.read(githubImportControllerProvider).query, '');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ничего не найдено'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ничего не найдено'), findsOneWidget);
      await tester.ensureVisible(find.text('Сбросить поиск и фильтры'));
      await tester.tap(find.text('Сбросить поиск и фильтры'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Загрузить ещё'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Загрузить ещё'));
      await tester.pumpAndSettle();
      expect(
        container.read(githubImportControllerProvider).repositories,
        hasLength(2),
      );
      expect(source.pageReads, 2);
      source.readProfile = () async =>
          throw const GitHubFailure(GitHubFailureKind.network);
      await tester.scrollUntilVisible(
        find.text('Обновить GitHub'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Обновить GitHub')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Обновить GitHub'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Нет соединения'));
      expect(find.text('Нет соединения'), findsOneWidget);
      expect(
        container.read(githubImportControllerProvider).repositories,
        hasLength(2),
      );
      source.readProfile = () async => _profile;
      await tester.drag(find.byType(ListView), const Offset(0, 2500));
      await tester.pumpAndSettle();
      final reads = source.profileReads;
      await tester.drag(find.byType(ListView), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(source.profileReads, reads + 1);
      expect(
        container.read(githubImportControllerProvider).repositories,
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A new username clears the input before pending debounce commits',
    (tester) async {
      final source = _Source();
      await _open(tester, source);
      await _submit(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('github_search')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('github_search')),
        'abc',
      );
      await tester.pump(const Duration(milliseconds: 100));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GitHubImportScreen)),
      );
      expect(container.read(githubImportControllerProvider).query, '');
      source.readProfile = () async => const GitHubProfile(
        id: 2,
        login: 'another',
        htmlUrl: 'https://github.com/another',
        publicRepositories: 1,
      );
      await container
          .read(githubImportControllerProvider.notifier)
          .load('another');
      await tester.pumpAndSettle();
      final input = tester.widget<TextFormField>(
        find.descendant(
          of: find.byKey(const ValueKey('github_search')),
          matching: find.byType(TextFormField),
        ),
      );
      expect(input.controller!.text, '');
      expect(
        container.read(githubImportControllerProvider).visibleRepositories,
        hasLength(1),
      );
      expect(find.text('@another'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('An empty public profile stays usable', (tester) async {
    final source = _Source()..empty = true;
    await _open(tester, source);
    await _submit(tester);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Публичных репозиториев нет'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Публичных репозиториев нет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final theme in [ThemeMode.dark, ThemeMode.light]) {
    for (final viewport in [
      const Size(320, 640),
      const Size(844, 390),
      const Size(768, 1024),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('GitHub loaded ${theme.name} $viewport text $scale', (
          tester,
        ) async {
          tester.view.physicalSize = viewport;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _open(tester, _Source(), theme: theme);
          await _submit(tester);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.drag(find.byType(ListView), const Offset(0, -3500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            final semantics = tester.ensureSemantics();
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            semantics.dispose();
          }
        });
      }
    }
  }
}

Future<void> _open(
  WidgetTester tester,
  _Source source, {
  ThemeMode theme = ThemeMode.dark,
}) async {
  await tester.pumpWidget(
    StackCardApp(
      initialLocation: '/github-import',
      initialThemeMode: theme,
      providerOverrides: [
        githubImportRepositoryProvider.overrideWithValue(source),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('github_username')),
    'octocat',
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(
    tester.element(find.text('Загрузить профиль')),
    alignment: 0.5,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Загрузить профиль'));
}

const _profile = GitHubProfile(
  id: 1,
  login: 'octocat',
  htmlUrl: 'https://github.com/octocat',
  publicRepositories: 2,
);

GitHubRepository _repository(int id) => GitHubRepository(
  id: id,
  name: id == 1 ? 'Source repository' : 'Next repository',
  fullName: 'octocat/source-$id',
  htmlUrl: 'https://github.com/octocat/source-$id',
  stars: 10,
  forks: 2,
  isFork: false,
  archived: false,
  updatedAt: DateTime.utc(2026, 10, 3),
  description: 'Публичный источник с длинным описанием для проверки переноса текста на узком экране.',
  language: 'Dart',
);

final class _Source implements GitHubImportRepository {
  int profileReads = 0;
  int pageReads = 0;
  bool empty = false;
  Future<GitHubProfile> Function() readProfile = () async => _profile;

  @override
  Future<GitHubProfile> getProfile(String username) {
    profileReads++;
    return readProfile();
  }

  @override
  Future<GitHubRepositoriesPage> getRepositories(
    GitHubProfile profile, {
    Uri? page,
  }) async {
    pageReads++;
    return GitHubRepositoriesPage(
      repositories: empty ? [] : [_repository(page == null ? 1 : 2)],
      nextPage: empty || page != null
          ? null
          : Uri.parse('https://api.github.com/user/1/repos?page=2'),
    );
  }

  @override
  void cancelRequests() {}
}
