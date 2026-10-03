import 'dart:async';

import 'package:app_stackcard/features/projects/projects.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Repository override supplies the full list and independent featured selection', () async {
    final featured = _project('Replacement case', featured: true);
    final regular = _project('Another case');
    final source = [featured, regular];
    final container = ProviderContainer.test(
      overrides: [
        projectsRepositoryProvider.overrideWithValue(
          _FakeProjectsRepository(() async => source),
        ),
      ],
    );

    expect(container.read(visibleProjectsProvider).isLoading, isTrue);
    expect(container.read(featuredProjectsProvider).isLoading, isTrue);
    final projects = await container.read(projectsProvider.future);
    container.read(projectFiltersProvider.notifier).setQuery('missing');
    container
        .read(projectFiltersProvider.notifier)
        .setFilter(ProjectFilter.manual);
    source.clear();

    expect(projects, [featured, regular]);
    expect(() => projects.clear(), throwsUnsupportedError);
    expect(container.read(visibleProjectsProvider).requireValue, isEmpty);
    expect(container.read(featuredProjectsProvider).requireValue, [featured]);
  });

  test(
    'Derived lists preserve repository errors without automatic retry',
    () async {
      var requests = 0;
      final failure = Exception('Unavailable source');
      final container = ProviderContainer.test(
        overrides: [
          projectsRepositoryProvider.overrideWithValue(
            _FakeProjectsRepository(() async {
              requests++;
              throw failure;
            }),
          ),
        ],
      );

      await expectLater(
        container.read(projectsProvider.future),
        throwsA(same(failure)),
      );
      await container.pump();

      expect(container.read(visibleProjectsProvider).error, same(failure));
      expect(container.read(featuredProjectsProvider).error, same(failure));
      expect(requests, 1);
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
    'ProjectsScreen renders an alternative repository without changing widgets',
    (tester) async {
      final replacement = _project('Replacement case', featured: true);
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/projects',
          providerOverrides: [
            projectsRepositoryProvider.overrideWithValue(
              _FakeProjectsRepository(() async => [replacement]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Проекты: 1'), findsOneWidget);
      expect(find.text('Replacement case'), findsOneWidget);
      expect(find.text('Atlas UI Kit'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProjectsScreen)),
      );
      expect(container.read(featuredProjectsProvider).requireValue, [
        replacement,
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Loading, failure and explicit retry use the same repository contract',
    (tester) async {
      var requests = 0;
      var pending = Completer<List<Project>>();
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/projects',
          providerOverrides: [
            projectsRepositoryProvider.overrideWithValue(
              _FakeProjectsRepository(() {
                requests++;
                return pending.future;
              }),
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Загрузка данных'), findsOneWidget);

      pending.completeError(Exception('Unavailable source'));
      await tester.pumpAndSettle();
      expect(find.text('Не удалось загрузить данные'), findsOneWidget);
      expect(requests, 1);

      pending = Completer<List<Project>>();
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      expect(find.text('Загрузка данных'), findsOneWidget);
      expect(requests, 2);
      pending.complete([_project('Recovered case')]);
      await tester.pumpAndSettle();

      expect(find.text('Recovered case'), findsOneWidget);
      expect(find.text('Проекты: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'An empty repository reaches the existing empty state and reset action',
    (tester) async {
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/projects',
          providerOverrides: [
            projectsRepositoryProvider.overrideWithValue(
              _FakeProjectsRepository(() async => []),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Проекты: 0'), findsOneWidget);
      expect(find.text('Ничего не найдено'), findsOneWidget);
      await tester.ensureVisible(find.text('Сбросить фильтры'));
      await tester.tap(find.text('Сбросить фильтры'));
      await tester.pumpAndSettle();
      expect(find.text('Проекты: 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Project _project(String title, {bool featured = false}) => Project(
  title: title,
  description: 'Repository replacement',
  technologies: ['Dart'],
  symbol: 'R',
  category: 'Mobile app',
  source: ProjectSource.github,
  featured: featured,
  details: 'Replacement details',
);

final class _FakeProjectsRepository implements ProjectsRepository {
  const _FakeProjectsRepository(this.read);

  final Future<List<Project>> Function() read;

  @override
  Future<List<Project>> getProjects() => read();
}
