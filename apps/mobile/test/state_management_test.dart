import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/core/state/settings_repository.dart';
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
    'Motion preference keeps the router and query survives routes without exposing legacy filters',
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
      await tester.ensureVisible(
        find.byKey(const Key('settings.reducedMotion')),
      );
      await tester.tap(find.byKey(const Key('settings.reducedMotion')));
      await tester.pumpAndSettle();
      expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byKey(const Key('settings.reducedMotion'))),
        ),
        isTrue,
      );
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig,
        same(router),
      );
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.widgetWithText(TextButton, 'Проекты'),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProjectsScreen)),
      );
      expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(ProjectsScreen)),
        ),
        isTrue,
      );
      container
          .read(projectFiltersProvider.notifier)
          .setFilter(ProjectFilter.manual);
      await tester.enterText(find.byType(TextFormField), 'React');
      await tester.pumpAndSettle();
      expect(find.text('Readme Studio'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Проекты: 1',
        ),
        findsOneWidget,
      );
      expect(find.byType(ChoiceChip), findsNothing);
      await tester.enterText(find.byType(TextFormField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('Ничего не найдено'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.widgetWithText(TextButton, 'Главная'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsScreen), findsNothing);
      await tester.ensureVisible(find.text('Портфолио пока пустое'));
      expect(find.text('Портфолио пока пустое'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.widgetWithText(TextButton, 'Проекты'),
        ),
      );
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
      expect(find.text('Очистить поиск'), findsNothing);
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Проекты: 4',
        ),
        findsOneWidget,
      );
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

  testWidgets('System preference follows OS brightness changes', (
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
    Brightness current() =>
        Theme.of(tester.element(find.text('Приложение'))).brightness;
    expect(current(), Brightness.light);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(current(), Brightness.dark);
  });

  testWidgets('Theme selector switches the app and persists the choice', (
    tester,
  ) async {
    final stored = <AppSettings>[];
    await tester.pumpWidget(
      StackCardApp(
        initialLocation: '/settings/appearance',
        settingsRepository: _MemorySettings(stored),
      ),
    );
    await tester.pumpAndSettle();
    Brightness current() =>
        Theme.of(tester.element(find.text('Приложение'))).brightness;
    expect(current(), Brightness.light);

    await tester.tap(find.byKey(const Key('settings.theme.dark')));
    await tester.pumpAndSettle();
    expect(current(), Brightness.dark);
    expect(stored.last.theme, AppTheme.dark);

    await tester.tap(find.byKey(const Key('settings.theme.light')));
    await tester.pumpAndSettle();
    expect(current(), Brightness.light);
    expect(stored.last.theme, AppTheme.light);
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
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Проекты: 1',
      ),
      findsOneWidget,
    );

    notifier.reset();
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Проекты: 4',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Remounting the app resets motion preference and product session state',
    (tester) async {
      await tester.pumpWidget(
        const StackCardApp(initialLocation: '/settings/appearance'),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('settings.reducedMotion')),
      );
      await tester.tap(find.byKey(const Key('settings.reducedMotion')));
      await tester.pumpAndSettle();
      expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byKey(const Key('settings.reducedMotion'))),
        ),
        isTrue,
      );
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.widgetWithText(TextButton, 'Проекты'),
        ),
      );
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
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Проекты: 4',
        ),
        findsOneWidget,
      );
      expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(ProjectsScreen)),
        ),
        isFalse,
      );
      expect(
        Theme.of(tester.element(find.byType(TextFormField))).brightness,
        Brightness.light,
      );
    },
  );
}

class _MemorySettings implements SettingsRepository {
  _MemorySettings(this.writes);
  final List<AppSettings> writes;

  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async => writes.add(settings);
}
