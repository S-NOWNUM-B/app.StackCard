import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/projects/projects.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    'Settings and empty Home defer the Projects repository until its root opens',
    (tester) async {
      final projects = TestProjectsRepository();
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/settings',
          providerOverrides: [
            projectsRepositoryProvider.overrideWithValue(projects),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(projects.calls, 0);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.text('Портфолио пока пустое'), findsOneWidget);
      expect(find.text('Replacement Project'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byType(TextButton),
        ),
        findsNWidgets(3),
      );
      expect(find.text('Резюме'), findsNothing);
      expect(find.text('Портфолио'), findsNothing);
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
      expect(projects.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Legacy profile route guides migration and reads the draft without demo fallback',
    (tester) async {
      final repository = MemoryPortfolioDraftRepository();
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
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Выберите содержимое основного портфолио'),
        findsOneWidget,
      );
      expect(find.text('Private owner'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(find.byType(MainPortfolioEditorScreen), findsOneWidget);
      final model = container.read(portfolioDraftControllerProvider).content!;
      expect(model.profile.name, 'Private owner');
      expect(model.profile.headline, 'Dart engineer');
      expect(model.skills.map((skill) => skill.name), ['Dart']);
      expect((await repository.read())!.revision, 1);
      expect(find.text('Private notes'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(find.text('Портфолио пока пустое'), findsOneWidget);
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
