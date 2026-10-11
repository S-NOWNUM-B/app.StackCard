import 'package:app_stackcard/features/github_import/data/github_response_cache.dart';
import 'package:app_stackcard/features/github_import/github_import.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<MemoryPortfolioDraftRepository> _seed() async {
  final repository = MemoryPortfolioDraftRepository();
  await repository.save(
    PortfolioContent(
      githubUsername: 'owner',
      projects: [
        PortfolioProject(
          id: 'project',
          title: 'Сохранённый проект',
          description: '',
          technologies: const [],
        ),
      ],
      profile: const PortfolioProfile(name: 'Сохранённое имя'),
    ),
    notes: 'Сохранённые приватные заметки',
    expectedRevision: 0,
  );
  return repository;
}

Future<void> _open(
  WidgetTester tester,
  MemoryPortfolioDraftRepository repository,
  String path, {
  _Cache? cache,
}) async {
  await tester.pumpWidget(
    StackCardApp(
      initialLocation: path,
      providerOverrides: [
        portfolioDraftRepositoryProvider.overrideWithValue(repository),
        if (cache != null) githubResponseCacheProvider.overrideWithValue(cache),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Settings has only modern groups and account below separator', (
    tester,
  ) async {
    await _open(tester, await _seed(), '/settings');
    for (final group in [
      'account',
      'github',
      'appearance',
      'inbox',
      'notifications',
      'about',
    ]) {
      expect(find.byKey(Key('settings.group.$group')), findsOneWidget);
    }
    for (final group in ['profile', 'contacts', 'privacy']) {
      expect(find.byKey(Key('settings.group.$group')), findsNothing);
    }
    expect(find.text('Гостевой'), findsNothing);
    expect(find.textContaining('Перенести'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'GitHub save normalizes identity without persisting neighboring buffer',
    (tester) async {
      final repository = await _seed();
      await _open(tester, repository, '/settings/github');
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('settings.github.save'))),
      );
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      final working = container.read(portfolioDraftControllerProvider).content!;
      controller.updateContent(
        working.copyWith(
          profile: working.profile.copyWith(name: 'Несохранённое имя'),
        ),
      );
      controller.updateNotes('Несохранённые заметки');
      await tester.enterText(
        find.byKey(const Key('settings.github.username')),
        ' https://github.com/NEW-OWNER/ ',
      );
      await _tap(tester, const Key('settings.github.save'));
      final saved = (await repository.read())!;
      expect(saved.content!.githubUsername, 'new-owner');
      expect(saved.content!.profile.name, 'Сохранённое имя');
      expect(saved.notes, 'Сохранённые приватные заметки');
      expect(
        container.read(portfolioDraftControllerProvider).content!.profile.name,
        'Несохранённое имя',
      );
      expect(
        container.read(portfolioDraftControllerProvider).notes,
        'Несохранённые заметки',
      );
      expect(saved.content!.projects.single.id, 'project');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Invalid GitHub identity stays in form and does not save', (
    tester,
  ) async {
    final repository = await _seed();
    await _open(tester, repository, '/settings/github');
    await tester.enterText(
      find.byKey(const Key('settings.github.username')),
      'https://github.com/owner/repository',
    );
    await _tap(tester, const Key('settings.github.save'));
    expect((await repository.read())!.content!.githubUsername, 'owner');
    expect(find.textContaining('Укажите имя пользователя'), findsOneWidget);
    final input = tester.widget<TextFormField>(
      find.descendant(
        of: find.byKey(const Key('settings.github.username')),
        matching: find.byType(TextFormField),
      ),
    );
    expect(input.controller!.text, 'https://github.com/owner/repository');
  });

  testWidgets(
    'Safe cache clear preserves exact durable portfolio and project data',
    (tester) async {
      final repository = await _seed();
      final before = await repository.read();
      final cache = _Cache();
      await cache.write(
        'public-response',
        const CachedGitHubResponse(body: '{}'),
      );
      await _open(tester, repository, '/settings/appearance', cache: cache);
      await _tap(tester, const Key('settings.clearCache'));
      expect(cache.clears, 1);
      expect(await cache.read('public-response'), isNull);
      expect((await repository.read())!.content, before!.content);
      expect((await repository.read())!.notes, before.notes);
      expect((await repository.read())!.revision, before.revision);
      expect(
        find.byKey(const Key('settings.sourceDescriptions')),
        findsNothing,
      );
      expect(find.byKey(const Key('settings.reducedMotion')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Cache implements GitHubResponseCache, ClearableGitHubResponseCache {
  final values = <String, CachedGitHubResponse>{};
  int clears = 0;
  @override
  Future<CachedGitHubResponse?> read(String key) async => values[key];
  @override
  Future<void> write(String key, CachedGitHubResponse response) async =>
      values[key] = response;
  @override
  Future<void> clear() async {
    clears++;
    values.clear();
  }
}
