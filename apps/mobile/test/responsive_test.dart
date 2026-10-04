import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  const viewports = {
    'phone_portrait': Size(390, 844),
    'phone_landscape': Size(844, 390),
    'tablet_portrait': Size(768, 1024),
    'tablet_landscape': Size(1024, 768),
    'small_phone': Size(320, 640),
  };
  for (final theme in [ThemeMode.dark, ThemeMode.light]) {
    for (final viewport in viewports.entries) {
      for (final scale in [1.0, 2.0]) {
        for (final route in [
          'sign-in',
          'home',
          'portfolio',
          'projects',
          'settings',
        ]) {
          testWidgets('${theme.name} ${viewport.key} text $scale /$route', (
            tester,
          ) async {
            tester.view.physicalSize = viewport.value;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await tester.pumpWidget(
              StackCardApp(initialLocation: '/$route', initialThemeMode: theme),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Первый экран без overflow',
            );
            if (scale == 1) {
              await _checkAccessibility(tester);
            }
            if (const bool.fromEnvironment('UPDATE_UI_PREVIEWS') &&
                scale == 1 &&
                viewport.key != 'small_phone') {
              await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile(
                  '../../../docs/design/previews/${route}_${theme.name}_${viewport.key}.png',
                ),
              );
            }
            final scroll = find.byType(SingleChildScrollView).last;
            await tester.drag(scroll, const Offset(0, -3000));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Конец страницы без overflow',
            );
          });
        }
      }
    }
  }
}

Future<void> _checkAccessibility(WidgetTester tester) async {
  // SDK guidelines считают обрезанные scroll-границей semantics полными
  // элементами. Проверяем весь rendered content при исходной ширине экрана,
  // как в portfolio_builder_visual_test; overflow и goldens остаются отдельно.
  final size = tester.view.physicalSize;
  final scroll = tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byType(SingleChildScrollView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  final extraHeight = scroll.position.maxScrollExtent.ceilToDouble();
  tester.view.physicalSize = Size(size.width, size.height + extraHeight + 16);
  await tester.pumpAndSettle();
  final semantics = tester.ensureSemantics();
  try {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  } finally {
    semantics.dispose();
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
  }
}
