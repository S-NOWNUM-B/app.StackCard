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
    'Theme keeps the router and project filters survive route removal',
    (tester) async {
      await tester.pumpWidget(const StackCardApp(initialLocation: '/settings'));
      await tester.pumpAndSettle();
      final router = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .routerConfig;

      await tester.tap(find.text('Светлая'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig,
        same(router),
      );
      await tester.tap(find.byIcon(Icons.layers_outlined).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'React');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Вручную'));
      await tester.pumpAndSettle();
      expect(find.text('Ничего не найдено'), findsOneWidget);

      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsScreen), findsNothing);
      expect(find.text('Внешний вид'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.layers_outlined).last);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'React',
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Вручную'))
            .selected,
        isTrue,
      );
      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Сделано тобой'))).brightness,
        Brightness.light,
      );
      await tester.ensureVisible(find.text('Сбросить фильтры'));
      await tester.tap(find.text('Сбросить фильтры'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.text('Проекты: 4'), findsOneWidget);
    },
  );

  testWidgets('System appearance responds to platform brightness changes', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      const StackCardApp(
        initialLocation: '/settings',
        initialThemeMode: ThemeMode.system,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Системная'))
          .selected,
      isTrue,
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
      await tester.pumpWidget(const StackCardApp(initialLocation: '/settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Светлая'));
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
        Theme.of(tester.element(find.text('Сделано тобой'))).brightness,
        Brightness.dark,
      );
    },
  );
}
