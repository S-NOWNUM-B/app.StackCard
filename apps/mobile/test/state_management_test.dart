import 'package:app_stackcard/features/projects/projects.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    'Theme keeps the router and query survives routes without exposing legacy filters',
    (tester) async {
      await tester.pumpWidget(const StackCardApp(initialLocation: '/home'));
      await tester.pumpAndSettle();
      final router = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .routerConfig;

      await tester.tap(find.byKey(const Key('app.settings')));
      await tester.pumpAndSettle();
      final appearance = find.byKey(const Key('settings.group.appearance'));
      await tester.ensureVisible(appearance);
      await tester.tap(appearance);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Светлая'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig,
        same(router),
      );
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.layers_outlined).last);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProjectsScreen)),
      );
      container
          .read(projectFiltersProvider.notifier)
          .setFilter(ProjectFilter.manual);
      await tester.enterText(find.byType(TextFormField), 'React');
      await tester.pumpAndSettle();
      expect(find.text('Readme Studio'), findsOneWidget);
      expect(find.text('Проекты: 1'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      await tester.enterText(find.byType(TextFormField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('Ничего не найдено'), findsOneWidget);

      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsScreen), findsNothing);
      expect(find.text('Привет, Alex'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.layers_outlined).last);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'missing',
      );
      expect(
        container.read(projectFiltersProvider).filter,
        ProjectFilter.manual,
      );
      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(TextFormField))).brightness,
        Brightness.light,
      );
      await tester.ensureVisible(find.text('Очистить поиск'));
      await tester.tap(find.text('Очистить поиск'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.text('Проекты: 4'), findsOneWidget);
      expect(
        container.read(projectFiltersProvider).filter,
        ProjectFilter.manual,
      );
      expect(
        container.read(visibleProjectsProvider).requireValue,
        hasLength(2),
        reason: 'Legacy provider filtering remains independent of Projects UI',
      );
    },
  );

  testWidgets('System appearance responds to platform brightness changes', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      const StackCardApp(
        initialLocation: '/settings/appearance',
        initialThemeMode: ThemeMode.system,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    expect(
      Theme.of(tester.element(find.text('Внешний вид'))).brightness,
      Brightness.light,
    );

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Внешний вид'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('External Riverpod updates synchronize the search controller', (
    tester,
  ) async {
    await tester.pumpWidget(const StackCardApp(initialLocation: '/projects'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProjectsScreen)),
    );
    final notifier = container.read(projectFiltersProvider.notifier);
    notifier.setQuery('Atlas');
    await tester.pumpAndSettle();
    final controller = tester
        .widget<TextFormField>(find.byType(TextFormField))
        .controller!;
    expect(controller.text, 'Atlas');
    expect(controller.selection, const TextSelection.collapsed(offset: 5));
    expect(find.text('Проекты: 1'), findsOneWidget);

    notifier.reset();
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    expect(find.text('Проекты: 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Remounting the app resets appearance and product session state',
    (tester) async {
      await tester.pumpWidget(
        const StackCardApp(initialLocation: '/settings/appearance'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Светлая'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.layers_outlined).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Atlas');
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const StackCardApp(initialLocation: '/projects'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.text('Проекты: 4'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(TextFormField))).brightness,
        Brightness.dark,
      );
    },
  );
}
