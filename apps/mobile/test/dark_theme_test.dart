import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/core/state/appearance_controller.dart';
import 'package:app_stackcard/core/theme/stackcard_colors.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_content_view.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
}

void main() {
  final palettes = {
    'light': StackCardColors.light,
    'dark': StackCardColors.dark,
  };

  for (final entry in palettes.entries) {
    group('${entry.key} palette', () {
      final c = entry.value;
      final surfaces = {
        'background': c.background,
        'surface': c.surface,
        'surfaceElevated': c.surfaceElevated,
        'surfaceHover': c.surfaceHover,
      };
      final texts = {
        'textPrimary': c.textPrimary,
        'textSecondary': c.textSecondary,
        'textMeta': c.textMeta,
        'textMuted': c.textMuted,
        'accentText': c.accentText,
        'successText': c.successText,
        'error': c.error,
      };
      for (final surface in surfaces.entries) {
        for (final text in texts.entries) {
          test('${text.key} on ${surface.key} meets WCAG AA text', () {
            expect(
              _contrast(text.value, surface.value),
              greaterThanOrEqualTo(4.5),
            );
          });
        }
        test('focus and control outline on ${surface.key} meet 3:1', () {
          expect(_contrast(c.focus, surface.value), greaterThanOrEqualTo(3));
          expect(
            _contrast(c.controlOutline, surface.value),
            greaterThanOrEqualTo(3),
          );
        });
      }
      test('primary pair meets AA', () {
        expect(_contrast(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5));
        expect(_contrast(c.paper, c.ink), greaterThanOrEqualTo(4.5));
      });
    });
  }

  test('Dark ThemeData is a real dark Material 3 theme', () {
    final dark = StackCardTheme.dark;
    final light = StackCardTheme.light;
    expect(dark.useMaterial3, isTrue);
    expect(dark.brightness, Brightness.dark);
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(dark.scaffoldBackgroundColor, StackCardColors.dark.background);
    expect(dark.extension<StackCardColors>(), StackCardColors.dark);
    expect(light.brightness, Brightness.light);
    expect(light.scaffoldBackgroundColor, StackCardColors.light.background);
    expect(dark.scaffoldBackgroundColor, isNot(light.scaffoldBackgroundColor));
    final scheme = dark.colorScheme;
    expect(_contrast(scheme.onSurface, scheme.surface), greaterThan(4.5));
    expect(_contrast(scheme.onPrimary, scheme.primary), greaterThan(4.5));
    expect(_contrast(scheme.onError, scheme.error), greaterThan(4.5));
    expect(
      _contrast(scheme.onInverseSurface, scheme.inverseSurface),
      greaterThan(4.5),
    );
  });

  test('Appearance controller maps every theme choice and notifies', () {
    final controller = AppearanceController(
      initialSettings: const AppSettings(theme: AppTheme.system),
    );
    addTearDown(controller.dispose);
    expect(controller.themeMode, ThemeMode.system);
    var notified = 0;
    controller.addListener(() => notified++);
    controller.setThemeMode(ThemeMode.dark);
    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.settings.theme, AppTheme.dark);
    controller.setThemeMode(ThemeMode.light);
    expect(controller.settings.theme, AppTheme.light);
    controller.setThemeMode(ThemeMode.light);
    expect(notified, 2);
  });

  testWidgets('Preview content stays light inside the dark app theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StackCardTheme.light,
        darkTheme: StackCardTheme.dark,
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PortfolioContentView(
              content: PortfolioContent(
                profile: const PortfolioProfile(name: 'Тестовый профиль'),
              ),
            ),
          ),
        ),
      ),
    );
    final scaffold = tester.element(find.byType(Scaffold));
    // Хром следует тёмной теме, документ внутри — светлая палитра.
    expect(Theme.of(scaffold).brightness, Brightness.dark);
    final name = find.text('Тестовый профиль');
    expect(name, findsOneWidget);
    final inner = tester.element(name);
    expect(Theme.of(inner).brightness, Brightness.light);
    expect(inner.colors.surface, StackCardColors.light.surface);
    final text = tester.renderObject<RenderParagraph>(name).text;
    expect(text.style!.color, StackCardColors.light.textPrimary);
    final surface = find.ancestor(
      of: name,
      matching: find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == StackCardColors.light.surface,
      ),
    );
    expect(surface, findsOneWidget);
  });

  const routes = [
    '/home',
    '/projects',
    '/editor',
    '/settings',
    '/settings/appearance',
    '/settings/github',
    '/sign-in',
    '/register',
    '/github-import',
    '/personalization',
    '/inbox',
  ];
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final route in routes) {
      testWidgets(
        '${theme.name} $route renders without hardcoded light colors',
        (tester) async {
          final view = tester.view;
          view.physicalSize = const Size(390, 844);
          view.devicePixelRatio = 1;
          addTearDown(view.reset);
          await tester.pumpWidget(
            StackCardApp(
              initialLocation: route,
              initialSettings: AppSettings(theme: theme),
            ),
          );
          if (route == '/personalization') {
            // Экран держит бесконечный индикатор: settle не наступает.
            await tester.pump(const Duration(seconds: 1));
          } else {
            await tester.pumpAndSettle();
          }
          final isDark = theme == AppTheme.dark;
          final palette = isDark ? StackCardColors.dark : StackCardColors.light;
          final context = tester.element(find.byType(Scaffold).first);
          expect(
            Theme.of(context).brightness,
            isDark ? Brightness.dark : Brightness.light,
          );
          expect(Theme.of(context).scaffoldBackgroundColor, palette.background);

          // В тёмной теме не остаётся белых поверхностей и чёрного текста
          // на тёмном фоне: хардкод светлых цветов ломает контраст.
          if (isDark) {
            for (final element in find.byType(Material).evaluate()) {
              final color = (element.widget as Material).color;
              expect(color, isNot(Colors.white), reason: '$route Material');
            }
            for (final element in find.byType(ColoredBox).evaluate()) {
              final color = (element.widget as ColoredBox).color;
              expect(color, isNot(Colors.white), reason: '$route ColoredBox');
            }
            for (final element in find.byType(RichText).evaluate()) {
              final span = (element.renderObject as RenderParagraph).text;
              final color = span.style?.color;
              // onPrimary — тёмный текст на светлой primary-кнопке и индикаторе.
              if (color == null || color == palette.onPrimary) continue;
              expect(
                color.computeLuminance(),
                greaterThan(0.1),
                reason: '$route near-black text "${span.toPlainText()}"',
              );
            }
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
