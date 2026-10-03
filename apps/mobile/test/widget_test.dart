import 'package:app_stackcard/main.dart';
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
    expect(find.text('STACKCARD / DEMO'), findsOneWidget);
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
      for (final icon in [
        Icons.badge_outlined,
        Icons.layers_outlined,
        Icons.tune_rounded,
      ]) {
        await tester.tap(find.byIcon(icon).last);
        await tester.pumpAndSettle();
      }
      expect(find.text('Внешний вид'), findsOneWidget);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.text('Сделано тобой'), findsOneWidget);
      await tester.tap(find.byTooltip('Экран входа'));
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
      await tester.ensureVisible(find.text('Сбросить фильтры'));
      await tester.tap(find.text('Сбросить фильтры'));
      await tester.pumpAndSettle();
      expect(find.text('Проекты: 4'), findsOneWidget);
      await tester.ensureVisible(find.text('Посмотреть Atlas UI Kit'));
      await tester.tap(find.text('Посмотреть Atlas UI Kit'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets('Appearance updates app and all state previews work with retry', (
    tester,
  ) async {
    await tester.pumpWidget(const StackCardApp(initialLocation: '/settings'));
    await tester.pumpAndSettle();
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
    await tester.ensureVisible(find.text('Ошибка'));
    await tester.tap(find.text('Ошибка'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Повторить'));
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Здесь появятся ваши проекты'), findsOneWidget);
    await tester.ensureVisible(find.text('Загрузка'));
    await tester.tap(find.text('Загрузка'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Пусто'));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

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
      expect(find.text('STACKCARD / DEMO'), findsOneWidget);
      NavigationDestination? destination;
      for (var i = 0; i < 12 && destination?.label != 'Проекты'; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        destination = FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<NavigationDestination>();
      }
      expect(destination?.label, 'Проекты');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Сделано тобой'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
