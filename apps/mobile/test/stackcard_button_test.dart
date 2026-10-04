import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _label = 'Continue';
const _primaryRed = Color(0xFFE60010);

Future<void> _pumpButton(
  WidgetTester tester,
  ThemeData theme, {
  VoidCallback? onPressed,
  bool primary = true,
  bool loading = false,
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
              label: _label,
              icon: Icons.arrow_forward,
              onPressed: onPressed,
              primary: primary,
              loading: loading,
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
  expect(background, _primaryRed);
  expect(foreground, Colors.white);
  expect(_contrast(background, foreground), greaterThanOrEqualTo(4.5));
  if (loading) {
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .color,
      Colors.white,
    );
  } else {
    expect(
      _renderedTextColor(
        tester,
        find.descendant(of: find.byType(Icon), matching: find.byType(RichText)),
      ),
      Colors.white,
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
      expect(disabledBackground, isNot(_primaryRed));
      expect(disabledForeground, isNot(Colors.white));
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
      expect(secondaryBackground, isNot(_primaryRed));
      expect(secondaryForeground, theme.colorScheme.onSurface);
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
  }
}
