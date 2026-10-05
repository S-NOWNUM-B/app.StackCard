import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_colors.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:app_stackcard/shared/widgets/stackcard_input.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _label = 'Continue';

Future<void> _pumpButton(
  WidgetTester tester,
  ThemeData theme, {
  VoidCallback? onPressed,
  bool primary = true,
  bool loading = false,
  StackCardButtonRole? role,
  String? unavailableReason,
  String label = _label,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 240,
            child: StackCardButton(
              label: label,
              icon: Icons.arrow_forward,
              onPressed: onPressed,
              primary: primary,
              loading: loading,
              role: role,
              unavailableReason: unavailableReason,
            ),
          ),
        ),
      ),
    ),
  );
  if (loading) {
    await tester.pump(const Duration(milliseconds: 300));
  } else {
    await tester.pumpAndSettle();
  }
}

Color _background(WidgetTester tester) => tester
    .widget<Material>(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Material),
      ),
    )
    .color!;

Color _renderedTextColor(WidgetTester tester, Finder finder) =>
    (tester.renderObject<RenderParagraph>(finder).text as TextSpan)
        .style!
        .color!;

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
}

void _expectPrimary(WidgetTester tester, {bool loading = false}) {
  final background = _background(tester);
  final foreground = _renderedTextColor(tester, find.text(_label));
  final colors = tester.element(find.text(_label)).colors;
  expect(background, isIn([colors.primary, colors.accentHover]));
  expect(foreground, colors.onPrimary);
  expect(_contrast(background, foreground), greaterThanOrEqualTo(4.5));
  if (loading) {
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .color,
      colors.onPrimary,
    );
  } else {
    expect(
      _renderedTextColor(
        tester,
        find.descendant(of: find.byType(Icon), matching: find.byType(RichText)),
      ),
      colors.onPrimary,
    );
  }
}

Future<void> _checkAccessibility(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();
  try {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  } finally {
    semantics.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manrope = FontLoader('Manrope');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      manrope.addFont(rootBundle.load('assets/fonts/Manrope-$weight.ttf'));
    }
    await manrope.load();
    for (final entry in [
      ('DM Sans', 'assets/fonts/DM_Sans.ttf'),
      ('Noto Sans', 'assets/fonts/Noto_Sans.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(entry.$1)..addFont(rootBundle.load(entry.$2));
      await loader.load();
    }
  });

  for (final configuration in [
    ('dark', StackCardTheme.dark),
    ('light', StackCardTheme.light),
    ('authentication dark', StackCardTheme.authentication(StackCardTheme.dark)),
    (
      'authentication light',
      StackCardTheme.authentication(StackCardTheme.light),
    ),
  ]) {
    testWidgets('${configuration.$1} primary colors and interaction states', (
      tester,
    ) async {
      final theme = configuration.$2;
      final colors = theme.extension<StackCardColors>()!;
      var presses = 0;
      void onPressed() => presses++;

      await _pumpButton(tester, theme, onPressed: onPressed);
      _expectPrimary(tester);
      await _checkAccessibility(tester);

      final button = find.byType(FilledButton);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(button));
      await tester.pumpAndSettle();
      _expectPrimary(tester);

      await mouse.down(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 200));
      _expectPrimary(tester);
      await mouse.up();
      await mouse.moveTo(Offset.zero);
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(presses, 1);

      final focus = Focus.of(tester.element(find.text(_label)));
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      _expectPrimary(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(presses, 2);

      await _pumpButton(tester, theme, onPressed: onPressed, loading: true);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      _expectPrimary(tester, loading: true);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 200));
      expect(presses, 2);

      await _pumpButton(tester, theme);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final disabledBackground = _background(tester);
      final disabledForeground = _renderedTextColor(tester, find.text(_label));
      expect(disabledBackground, isNot(colors.primary));
      expect(disabledForeground, colors.textSecondary);
      expect(
        _contrast(disabledBackground, disabledForeground),
        greaterThanOrEqualTo(4.5),
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(presses, 2);

      await _pumpButton(tester, theme, primary: false, onPressed: onPressed);
      final secondaryBackground = _background(tester);
      final secondaryForeground = _renderedTextColor(tester, find.text(_label));
      expect(secondaryBackground, isNot(colors.primary));
      expect(secondaryForeground, colors.textPrimary);
      expect(
        _contrast(secondaryBackground, secondaryForeground),
        greaterThanOrEqualTo(4.5),
      );
      await _checkAccessibility(tester);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(presses, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${configuration.$1} Tab focus and full target activate once', (
      tester,
    ) async {
      var presses = 0;
      final theme = configuration.$2;
      await _pumpButton(tester, theme, onPressed: () => presses++);
      final semantics = tester.ensureSemantics();
      try {
        final control = find.bySemanticsLabel(_label);
        final beforeFocus = tester.getRect(control);
        expect(beforeFocus.width, greaterThanOrEqualTo(48));
        expect(beforeFocus.height, greaterThanOrEqualTo(48));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(control),
          isSemantics(
            label: _label,
            isButton: true,
            isEnabled: true,
            isFocused: true,
            hasTapAction: true,
          ),
        );
        expect(tester.getRect(control), beforeFocus);
        final colors = theme.extension<StackCardColors>()!;
        final rings = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(StackCardButton),
                matching: find.byType(DecoratedBox),
              ),
            )
            .where((widget) {
              final decoration = widget.decoration;
              return decoration is BoxDecoration &&
                  decoration.border is Border &&
                  (decoration.border! as Border).top.color == colors.focus;
            });
        expect(rings, isNotEmpty, reason: 'Tab должен дать видимый focus ring');
        expect(
          _contrast(colors.focus, theme.scaffoldBackgroundColor),
          greaterThanOrEqualTo(3),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(presses, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(presses, 2);

        await tester.tapAt(
          beforeFocus.topLeft + Offset(2, beforeFocus.height / 2),
        );
        await tester.pumpAndSettle();
        expect(
          presses,
          3,
          reason: 'Край target доступен вне Face, без двойного вызова',
        );
        tester.semantics.tap(find.semantics.byLabel(_label));
        await tester.pumpAndSettle();
        expect(presses, 4, reason: 'Доступное действие выполняется один раз');
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets(
      '${configuration.$1} loading transition blocks pointer and keys',
      (tester) async {
        var presses = 0;
        var loading = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: configuration.$2,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 240,
                  child: StatefulBuilder(
                    builder: (context, setState) => StackCardButton(
                      label: _label,
                      primary: true,
                      loading: loading,
                      unavailableReason:
                          'Публикация недоступна без подключения',
                      onPressed: () => setState(() {
                        presses++;
                        loading = true;
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final semantics = tester.ensureSemantics();
        try {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(presses, 1);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(
            find.text('Публикация недоступна без подключения'),
            findsNothing,
          );
          expect(
            tester.getSemantics(find.bySemanticsLabel(_label)),
            isSemantics(
              label: _label,
              isButton: true,
              isEnabled: false,
              isLiveRegion: true,
              hasTapAction: false,
              value: const AppStrings(Locale('ru')).tr('common.loading'),
            ),
          );
          await tester.tap(find.byType(FilledButton));
          await tester.tap(find.byType(FilledButton));
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pump(const Duration(milliseconds: 300));
          expect(presses, 1);
          _expectPrimary(tester, loading: true);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      '${configuration.$1} unavailable reason stays readable and inert',
      (tester) async {
        const reason = 'Сначала подключитесь к сети и сохраните изменения';
        final theme = configuration.$2;
        await _pumpButton(tester, theme, unavailableReason: reason);
        final semantics = tester.ensureSemantics();
        try {
          expect(find.text(reason), findsOneWidget);
          expect(
            tester.getSemantics(find.bySemanticsLabel(_label)),
            isSemantics(isButton: true, isEnabled: false, hasTapAction: false),
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(find.text(reason), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(
            _contrast(
              _renderedTextColor(tester, find.text(reason)),
              theme.scaffoldBackgroundColor,
            ),
            greaterThanOrEqualTo(4.5),
          );
          await _pumpButton(
            tester,
            theme,
            onPressed: () {},
            unavailableReason: reason,
          );
          expect(find.text(reason), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      '${configuration.$1} lifecycle removes stale focus and callback',
      (tester) async {
        final theme = configuration.$2;
        var presses = 0;
        await _pumpButton(tester, theme, unavailableReason: 'Недоступно');
        expect(
          tester.takeException(),
          isNull,
          reason: 'Initial disabled build',
        );
        final semantics = tester.ensureSemantics();
        try {
          expect(
            tester.getSemantics(find.bySemanticsLabel(_label)),
            isSemantics(
              isEnabled: false,
              isFocusable: false,
              hasTapAction: false,
            ),
          );
          await _pumpButton(tester, theme, onPressed: () => presses++);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(
            tester.getSemantics(find.bySemanticsLabel(_label)),
            isSemantics(isEnabled: true, isFocused: true, hasTapAction: true),
          );
          await _pumpButton(tester, theme, unavailableReason: 'Недоступно');
          expect(
            tester.takeException(),
            isNull,
            reason: 'Focused to disabled build',
          );
          expect(
            tester.getSemantics(find.bySemanticsLabel(_label)),
            isSemantics(
              isEnabled: false,
              isFocusable: false,
              hasTapAction: false,
            ),
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(presses, 0);
          await _pumpButton(
            tester,
            theme,
            onPressed: () => presses++,
            loading: true,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'Disabled to loading build',
          );
          await tester.tap(find.byType(FilledButton));
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pump(const Duration(milliseconds: 100));
          expect(presses, 0);
          await _pumpButton(tester, theme, onPressed: () => presses++);
          expect(
            tester.takeException(),
            isNull,
            reason: 'Loading to enabled build',
          );
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(presses, 1);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        } finally {
          semantics.dispose();
        }
      },
    );

    for (final role in StackCardButtonRole.values) {
      for (final label in [
        'Сохранить изменения выбранного документа и продолжить редактирование',
        'Apply changes to the selected document and continue editing',
      ]) {
        testWidgets('${configuration.$1} ${role.name} $label at text 2', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final theme = configuration.$2;
          await _pumpButton(
            tester,
            theme,
            onPressed: () {},
            role: role,
            label: label,
          );
          final background = _background(tester);
          final resolvedBackground = Color.alphaBlend(
            background,
            theme.scaffoldBackgroundColor,
          );
          expect(
            _contrast(
              resolvedBackground,
              _renderedTextColor(tester, find.text(label)),
            ),
            greaterThanOrEqualTo(4.5),
          );
          if (role != StackCardButtonRole.primary) {
            expect(
              background,
              isNot(theme.colorScheme.primary),
              reason: 'Явная роль должна переопределить legacy primary=true',
            );
          }
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          final style = (paragraph.text as TextSpan).style!;
          expect(style.fontFamily, 'Manrope');
          expect(style.fontFamilyFallback, contains('Noto Sans'));
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(paragraph.maxLines, isNull);
          expect(
            tester.getSize(find.byType(StackCardButton)).height,
            greaterThanOrEqualTo(48),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets(
      '${configuration.$1} input keeps its name and failed edit at text 2',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        const error =
            'Укажите название проекта. Несохранённый ввод остаётся доступен '
            'для исправления и не заменяет опубликованный документ.';
        final form = GlobalKey<FormState>();
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: configuration.$2,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: form,
                  child: StackCardInput(
                    label: 'Поиск проектов',
                    showLabel: false,
                    hint: 'Название',
                    controller: controller,
                    validator: (_) => error,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final semantics = tester.ensureSemantics();
        try {
          final field = find.byType(TextFormField);
          expect(tester.getSize(field).height, greaterThanOrEqualTo(56));
          final textField = tester.widget<TextField>(find.byType(TextField));
          expect(textField.decoration?.labelText, isNull);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText))
                .focusNode
                .hasFocus,
            isTrue,
          );
          await tester.enterText(field, 'Незавершённый проект');
          expect(form.currentState!.validate(), isFalse);
          await tester.pumpAndSettle();
          expect(controller.text, 'Незавершённый проект');
          expect(find.text(error), findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(error),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(paragraph.maxLines, isNull);
          expect(find.bySemanticsLabel(RegExp('Поиск проектов')), findsWidgets);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
