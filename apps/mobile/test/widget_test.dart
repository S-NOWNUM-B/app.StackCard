import 'package:app_stackcard/main.dart';
import 'package:app_stackcard/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  testWidgets('Demo entry validates email and opens navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const StackCardApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'invalid');
    await tester.ensureVisible(find.text('Открыть демо'));
    await tester.tap(find.text('Открыть демо'));
    await tester.pumpAndSettle();
    expect(find.text('Укажите корректный email'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'alex@example.dev');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Привет, Alex'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
    'Shell visits all destinations and back restores previous screen',
    (tester) async {
      await tester.pumpWidget(const StackCardApp(initialLocation: '/home'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Моё портфолио'));
      await tester.tap(find.text('Моё портфолио'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Предпросмотр'));
      await tester.tap(find.text('Предпросмотр'));
      await tester.pumpAndSettle();
      expect(find.text('Предпросмотр портфолио'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.text('Привет, Alex'), findsOneWidget);
      for (final icon in [Icons.badge_outlined, Icons.layers_outlined]) {
        await tester.tap(find.byIcon(icon).last);
        await tester.pumpAndSettle();
      }
      expect(find.text('Проекты: 4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('app.settings')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.text('Проекты: 4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('app.settings')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Вернуться ко входу'));
      await tester.tap(find.text('Вернуться ко входу'));
      await tester.pumpAndSettle();
      expect(find.text('Открыть демо'), findsOneWidget);
    },
  );

  testWidgets(
    'Project search filters by technology, empty result can reset and details close',
    (tester) async {
      await tester.pumpWidget(const StackCardApp(initialLocation: '/projects'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'React');
      await tester.pumpAndSettle();
      expect(find.text('Проекты: 1'), findsOneWidget);
      expect(find.text('Readme Studio'), findsOneWidget);
      expect(find.text('Atlas UI Kit'), findsNothing);
      await tester.enterText(find.byType(TextFormField), 'no-such-project');
      await tester.pumpAndSettle();
      expect(find.text('Ничего не найдено'), findsOneWidget);
      await tester.ensureVisible(find.text('Очистить поиск'));
      await tester.tap(find.text('Очистить поиск'));
      await tester.pumpAndSettle();
      expect(find.text('Проекты: 4'), findsOneWidget);
      final preview = find.byKey(
        const ValueKey('project_preview_Atlas UI Kit'),
      );
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets(
    'Settings opens appearance and account routes with working back',
    (tester) async {
      await tester.pumpWidget(const StackCardApp(initialLocation: '/settings'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      final router = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .routerConfig;
      final appearance = find.byKey(const Key('settings.group.appearance'));
      await tester.ensureVisible(appearance);
      await tester.tap(appearance);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      await tester.tap(find.text('Светлая'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Внешний вид'))).brightness,
        Brightness.light,
      );
      await tester.tap(find.text('Тёмная'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Внешний вид'))).brightness,
        Brightness.dark,
      );
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig,
        same(router),
      );
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      final account = find.byKey(const Key('settings.group.account'));
      await tester.ensureVisible(account);
      await tester.tap(account);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsAccountScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Keyboard reaches form, submits and activates a navigation control',
    (tester) async {
      await tester.pumpWidget(const StackCardApp());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Привет, Alex'), findsOneWidget);
      final destination = find.widgetWithText(TextButton, 'Проекты');
      var focused = false;
      for (var i = 0; i < 24 && !focused; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        focused = identical(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<TextButton>(),
          tester.widget<TextButton>(destination),
        );
      }
      expect(focused, isTrue, reason: 'Tab reaches the Projects destination');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Проекты: 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
