import 'dart:async';

import 'package:app_stackcard/features/profile/profile.dart';
import 'package:app_stackcard/features/projects/projects.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
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

  testWidgets('Repository replacements reach Home, Portfolio and preview', (
    tester,
  ) async {
    final profile = TestProfileRepository();
    final projects = TestProjectsRepository();
    await tester.pumpWidget(
      StackCardApp(
        initialLocation: '/home',
        providerOverrides: [
          profileRepositoryProvider.overrideWithValue(profile),
          projectsRepositoryProvider.overrideWithValue(projects),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Привет, Sam'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('1 проект'), findsOneWidget);
    expect(find.text('1 навык'), findsOneWidget);
    expect(find.text('Replacement Project'), findsOneWidget);
    expect(find.text('Alex Morgan'), findsNothing);
    await tester.ensureVisible(find.text('Моё портфолио'));
    await tester.tap(find.text('Моё портфолио'));
    await tester.pumpAndSettle();
    expect(find.text('Sam Lee'), findsOneWidget);
    expect(find.text('Другой профиль из Repository'), findsOneWidget);
    expect(find.text('Replacement Project'), findsOneWidget);
    expect(find.text('Frontend Developer'), findsNothing);
    await tester.ensureVisible(find.text('Предпросмотр'));
    await tester.tap(find.text('Предпросмотр'));
    await tester.pumpAndSettle();
    expect(find.text('Предпросмотр портфолио'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Sam Lee'),
      ),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Sam Lee · sam'), findsOneWidget);
    expect(find.text('Alex Morgan · alex-dev-demo'), findsNothing);
    expect(profile.calls, 1);
    expect(projects.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pending profile shows loading then the repository result', (
    tester,
  ) async {
    final pending = Completer<Profile>();
    await tester.pumpWidget(
      StackCardApp(
        initialLocation: '/portfolio',
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
    expect(find.text('Sam Lee'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'Failed profile has an explicit retry and does not expose internals',
    (tester) async {
      final profile = TestProfileRepository(failFirst: true);
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/home',
          providerOverrides: [
            profileRepositoryProvider.overrideWithValue(profile),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Не удалось загрузить данные'), findsOneWidget);
      expect(find.textContaining('test failure'), findsNothing);
      expect(profile.calls, 1);
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Привет, Sam'), findsOneWidget);
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
        initialLocation: '/portfolio',
        providerOverrides: [
          profileRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Загрузка данных'), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
    expect(repository.calls, 2);
    pending.complete(sampleProfile());
    await tester.pumpAndSettle();
    expect(find.text('Sam Lee'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home handles a repository with no featured projects', (
    tester,
  ) async {
    await tester.pumpWidget(
      StackCardApp(
        initialLocation: '/home',
        providerOverrides: [
          projectsRepositoryProvider.overrideWithValue(
            TestProjectsRepository(empty: true),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Нет избранных проектов'), findsOneWidget);
    expect(find.text('0 проектов'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
