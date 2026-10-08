import 'dart:async';

import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/profile/profile.dart';
import 'package:app_stackcard/features/projects/projects.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Profile sampleProfile() => Profile(
  name: 'Sam Lee',
  handle: 'sam',
  role: 'Dart Developer',
  location: 'Алматы',
  initials: 'SL',
  about: 'Другой профиль из Repository',
  skills: ['Dart'],
  readiness: ProfileReadiness(completedBlocks: 2, totalBlocks: 5),
);

class TestProfileRepository implements ProfileRepository {
  TestProfileRepository({this.pending, this.failFirst = false});
  final Future<Profile>? pending;
  final bool failFirst;
  int calls = 0;

  @override
  Future<Profile> getProfile() async {
    calls++;
    if (failFirst && calls == 1) throw StateError('test failure');
    return pending ?? sampleProfile();
  }
}

class TestProjectsRepository implements ProjectsRepository {
  TestProjectsRepository({this.empty = false});
  final bool empty;
  int calls = 0;

  @override
  Future<List<Project>> getProjects() async {
    calls++;
    return empty
        ? []
        : [
            Project(
              title: 'Replacement Project',
              description: 'Проект из другого источника',
              technologies: ['Dart'],
              symbol: 'R',
              category: 'Mobile app',
              source: ProjectSource.manual,
              featured: true,
              details: 'Другие детали',
            ),
          ];
  }
}

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
    'Repository replacements reach Settings and Projects without filling private libraries',
    (tester) async {
      final profile = TestProfileRepository();
      final projects = TestProjectsRepository();
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/settings',
          providerOverrides: [
            profileRepositoryProvider.overrideWithValue(profile),
            projectsRepositoryProvider.overrideWithValue(projects),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sam Lee · sam'), findsOneWidget);
      expect(find.text('Alex Morgan · alex-dev-demo'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final model = await container.read(profileProvider.future);
      expect(model.name, 'Sam Lee');
      expect(model.readiness.percent, 40);
      expect(model.skills, ['Dart']);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.text('Здесь появятся твои работы'), findsOneWidget);
      expect(find.text('Replacement Project'), findsNothing);
      await tester.tap(_destination('Портфолио'));
      await tester.pumpAndSettle();
      expect(find.text('Пока нет портфолио'), findsOneWidget);
      expect(find.text('Sam Lee'), findsNothing);
      await tester.tap(_destination('Проекты'));
      await tester.pumpAndSettle();
      expect(find.text('Replacement Project'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Проекты: 1',
        ),
        findsOneWidget,
      );
      expect(
        container.read(featuredProjectsProvider).requireValue.single.title,
        'Replacement Project',
      );
      expect(profile.calls, 1);
      expect(projects.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Developer Profile uses the overridden draft and never reads a demo profile',
    (tester) async {
      final repository = MemoryPortfolioDraftRepository();
      final demo = TestProfileRepository();
      await repository.save(
        PortfolioContent(
          profile: const PortfolioProfile(
            name: 'Private owner',
            headline: 'Dart engineer',
          ),
          skills: const [Skill(id: 'skill-dart', name: 'Dart')],
        ),
        expectedRevision: 0,
        notes: 'Private notes',
      );
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/settings/profile',
          providerOverrides: [
            portfolioDraftRepositoryProvider.overrideWithValue(repository),
            profileRepositoryProvider.overrideWithValue(demo),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private owner'), findsOneWidget);
      expect(find.text('Sam Lee'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final model = await container.read(profileProvider.future);
      expect(model.name, 'Private owner');
      expect(model.role, 'Dart engineer');
      expect(model.skills, ['Dart']);
      expect(demo.calls, 0);
      expect((await repository.read())!.revision, 1);
      expect(find.text('Private notes'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Pending profile shows loading then the repository result', (
    tester,
  ) async {
    final pending = Completer<Profile>();
    await tester.pumpWidget(
      StackCardApp(
        initialLocation: '/settings',
        providerOverrides: [
          profileRepositoryProvider.overrideWithValue(
            TestProfileRepository(pending: pending.future),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('Загрузка данных'), findsOneWidget);
    pending.complete(sampleProfile());
    await tester.pumpAndSettle();
    expect(find.text('Sam Lee · sam'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'Failed profile has an explicit retry and does not expose internals',
    (tester) async {
      final profile = TestProfileRepository(failFirst: true);
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/settings',
          providerOverrides: [
            profileRepositoryProvider.overrideWithValue(profile),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Не удалось загрузить данные'), findsOneWidget);
      expect(find.textContaining('test failure'), findsNothing);
      expect(profile.calls, 1);
      await tester.ensureVisible(find.text('Повторить'));
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Sam Lee · sam'), findsOneWidget);
      expect(profile.calls, 2);
    },
  );

  testWidgets('Retry replaces the retained error with a pending state', (
    tester,
  ) async {
    final pending = Completer<Profile>();
    final repository = TestProfileRepository(
      failFirst: true,
      pending: pending.future,
    );
    await tester.pumpWidget(
      StackCardApp(
        initialLocation: '/settings',
        providerOverrides: [
          profileRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Повторить'));
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Загрузка данных'), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
    expect(repository.calls, 2);
    pending.complete(sampleProfile());
    await tester.pumpAndSettle();
    expect(find.text('Sam Lee · sam'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home empty state does not consume a demo projects repository', (
    tester,
  ) async {
    final repository = TestProjectsRepository(empty: true);
    await tester.pumpWidget(
      StackCardApp(
        initialLocation: '/home',
        providerOverrides: [
          projectsRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Здесь появятся твои работы'), findsOneWidget);
    expect(find.text('Нет избранных проектов'), findsNothing);
    expect(repository.calls, 0);
    await tester.tap(_destination('Проекты'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Проекты: 0',
      ),
      findsOneWidget,
    );
    expect(repository.calls, 1);
    expect(tester.takeException(), isNull);
  });
}

Finder _destination(String label) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.widgetWithText(TextButton, label),
);
