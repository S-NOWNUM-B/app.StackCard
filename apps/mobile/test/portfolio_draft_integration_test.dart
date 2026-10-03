import 'dart:async';

import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/profile/profile.dart';
import 'package:app_stackcard/features/projects/projects.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PortfolioContent _content() => PortfolioContent(
  profile: const PortfolioProfile(
    name: 'Taylor Ray',
    username: 'taylor-ray',
    headline: 'Dart engineer',
    bio: 'A story from the local Builder.',
    locationText: 'Almaty',
  ),
  skills: const [Skill(id: 's1', name: 'Dart')],
  projects: [
    PortfolioProject(
      id: 'p1',
      title: 'Visible work',
      description: 'Built by Taylor',
      technologies: ['Dart'],
      featured: true,
    ),
    PortfolioProject(
      id: 'p2',
      title: 'Hidden work',
      description: 'Private selection',
      technologies: [],
      featured: true,
      visible: false,
    ),
  ],
  links: const [
    SocialLink(id: 'l1', label: 'Website', url: 'https://example.com'),
  ],
  resumeText: 'First line\nSecond line',
);

Future<MemoryPortfolioDraftRepository> _repository() async {
  final repository = MemoryPortfolioDraftRepository();
  await repository.save(
    _content(),
    expectedRevision: 0,
    notes: 'Private notebook',
  );
  return repository;
}

void main() {
  test('Cold concurrent read models await one nonempty draft read without fallback or cancellation', () async {
    final pending = Completer<PortfolioDraft?>();
    final repository = _PendingDraftRepository(pending.future);
    final profileSource = _UnusedProfileRepository();
    final projectsSource = _UnusedProjectsRepository();
    final container = ProviderContainer(
      overrides: [
        portfolioDraftRepositoryProvider.overrideWithValue(repository),
        profileRepositoryProvider.overrideWithValue(profileSource),
        projectsRepositoryProvider.overrideWithValue(projectsSource),
      ],
    );
    addTearDown(container.dispose);
    final profileFuture = container.read(profileProvider.future);
    final projectsFuture = container.read(projectsProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(repository.readCalls, 1);
    expect(profileSource.calls, 0);
    expect(projectsSource.calls, 0);
    pending.complete(
      PortfolioDraft(
        notes: 'Private',
        revision: 1,
        updatedAt: DateTime.utc(2026),
        pendingSync: true,
        content: _content(),
      ),
    );
    expect(
      (await profileFuture.timeout(const Duration(seconds: 5))).name,
      'Taylor Ray',
    );
    expect(
      (await projectsFuture.timeout(const Duration(seconds: 5))).first.id,
      'p1',
    );
    expect(profileSource.calls, 0);
    expect(projectsSource.calls, 0);
    expect(repository.readCalls, 1);
  });

  test('A late failed initial draft read never calls demo sources or silently retries', () async {
    final pending = Completer<PortfolioDraft?>();
    final repository = _PendingDraftRepository(pending.future);
    final profileSource = _UnusedProfileRepository();
    final projectsSource = _UnusedProjectsRepository();
    final container = ProviderContainer(
      overrides: [
        portfolioDraftRepositoryProvider.overrideWithValue(repository),
        profileRepositoryProvider.overrideWithValue(profileSource),
        projectsRepositoryProvider.overrideWithValue(projectsSource),
      ],
    );
    addTearDown(container.dispose);
    final profileFailure = expectLater(
      container.read(profileProvider.future),
      throwsA(isA<PortfolioDraftFailure>()),
    );
    final projectsFailure = expectLater(
      container.read(projectsProvider.future),
      throwsA(isA<PortfolioDraftFailure>()),
    );
    await Future<void>.delayed(Duration.zero);
    pending.completeError(
      const PortfolioDraftFailure(PortfolioDraftFailureKind.corrupted),
    );
    await Future.wait([profileFailure, projectsFailure])
        .timeout(const Duration(seconds: 5));
    await container.pump();
    expect(container.read(profileProvider).error, isA<PortfolioDraftFailure>());
    expect(
      container.read(projectsProvider).error,
      isA<PortfolioDraftFailure>(),
    );
    expect(repository.readCalls, 1);
    expect(profileSource.calls, 0);
    expect(projectsSource.calls, 0);
  });

  test(
    'Failed draft read reaches read models and explicit reload recovers',
    () async {
      final repository = _ReadFailureRepository(await _repository());
      final container = ProviderContainer(
        overrides: [
          portfolioDraftRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final typedFailure = isA<PortfolioDraftFailure>().having(
        (failure) => failure.kind,
        'kind',
        PortfolioDraftFailureKind.unsupportedVersion,
      );
      await Future.wait([
        expectLater(
          container.read(profileProvider.future),
          throwsA(typedFailure),
        ),
        expectLater(
          container.read(projectsProvider.future),
          throwsA(typedFailure),
        ),
      ]);
      expect(repository.readCalls, 1);
      repository.failRead = false;
      await container.read(portfolioDraftControllerProvider.notifier).load();
      expect((await container.read(profileProvider.future)).name, 'Taylor Ray');
      expect((await container.read(projectsProvider.future)).first.id, 'p1');
    },
  );

  for (final route in ['/home', '/portfolio', '/projects', '/settings']) {
    testWidgets(
      'Draft read failure on $route is visible and retry reads the draft',
      (tester) async {
        final repository = _ReadFailureRepository(await _repository());
        await tester.pumpWidget(
          StackCardApp(
            initialLocation: route,
            providerOverrides: [
              portfolioDraftRepositoryProvider.overrideWithValue(repository),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Alex Morgan'), findsNothing);
        expect(find.text('Не удалось загрузить данные'), findsOneWidget);
        repository.failRead = false;
        await tester.ensureVisible(find.text('Повторить'));
        await tester.tap(find.text('Повторить'));
        await tester.pumpAndSettle();
        expect(find.text('Не удалось загрузить данные'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'Working draft drives profile, projects and featured without extra writes',
    () async {
      final repository = await _repository();
      final container = ProviderContainer(
        overrides: [
          portfolioDraftRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      await controller.load();
      final profile = await container.read(profileProvider.future);
      expect(profile.name, 'Taylor Ray');
      expect(profile.readiness.percent, 100);
      final projects = await container.read(projectsProvider.future);
      expect(projects.map((item) => item.id), ['p1', 'p2']);
      expect(selectFeaturedProjects(projects).map((item) => item.id), ['p1']);
      controller.updateContent(
        _content().copyWith(
          profile: _content().profile.copyWith(name: 'Morgan Lane'),
        ),
      );
      expect(
        (await container.read(profileProvider.future)).name,
        'Morgan Lane',
      );
      expect((await repository.read())!.content!.profile.name, 'Taylor Ray');
      await controller.save();
      expect((await repository.read())!.content!.profile.name, 'Morgan Lane');
      expect((await repository.read())!.notes, 'Private notebook');
    },
  );

  test('Project filters do not alter featured or the saved draft', () async {
    final repository = await _repository();
    final container = ProviderContainer(
      overrides: [
        portfolioDraftRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(portfolioDraftControllerProvider.notifier).load();
    await container.read(projectsProvider.future);
    container.read(projectFiltersProvider.notifier).setQuery('Hidden');
    final filtered = container.read(visibleProjectsProvider).requireValue;
    expect(filtered.single.id, 'p2');
    expect(
      container.read(featuredProjectsProvider).requireValue.single.id,
      'p1',
    );
    expect((await repository.read())!.revision, 1);
  });

  for (final route in ['/home', '/portfolio', '/projects', '/settings']) {
    for (final language in AppLanguage.values) {
      testWidgets(
        'Local draft on $route, ${language.name}, narrow enlarged text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final repository = await _repository();
          await tester.pumpWidget(
            StackCardApp(
              initialLocation: route,
              initialSettings: AppSettings(
                language: language,
                theme: AppTheme.light,
              ),
              providerOverrides: [
                portfolioDraftRepositoryProvider.overrideWithValue(repository),
              ],
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Alex Morgan'), findsNothing);
          expect(find.text('Private notebook'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(SingleChildScrollView).last,
            const Offset(0, -2500),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect((await repository.read())!.revision, 1);
        },
      );
    }
  }
}

class _ReadFailureRepository implements PortfolioDraftRepository {
  _ReadFailureRepository(this.delegate);
  final PortfolioDraftRepository delegate;
  bool failRead = true;
  int readCalls = 0;
  @override
  Future<PortfolioDraft?> read() async {
    readCalls++;
    if (failRead) {
      throw const PortfolioDraftFailure(
        PortfolioDraftFailureKind.unsupportedVersion,
      );
    }
    return delegate.read();
  }

  @override
  Future<PortfolioDraft> saveNotes(String notes) => delegate.saveNotes(notes);
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) =>
      delegate.save(content, expectedRevision: expectedRevision, notes: notes);
}

class _PendingDraftRepository implements PortfolioDraftRepository {
  _PendingDraftRepository(this.pending);
  final Future<PortfolioDraft?> pending;
  int readCalls = 0;
  @override
  Future<PortfolioDraft?> read() {
    readCalls++;
    return pending;
  }

  @override
  Future<PortfolioDraft> saveNotes(String notes) async =>
      throw UnimplementedError();
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async => throw UnimplementedError();
}

class _UnusedProfileRepository implements ProfileRepository {
  int calls = 0;
  @override
  Future<Profile> getProfile() async {
    calls++;
    throw StateError('Draft must gate the demo profile');
  }
}

class _UnusedProjectsRepository implements ProjectsRepository {
  int calls = 0;
  @override
  Future<List<Project>> getProjects() async {
    calls++;
    throw StateError('Draft must gate demo projects');
  }
}
