import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:app_stackcard/core/theme/stackcard_colors.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:app_stackcard/shared/widgets/stackcard_icon.dart';
import 'package:app_stackcard/shared/widgets/stackcard_technology_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> brandPaths;
  late String canonicalFlutter;
  late String compatibleFlutter;
  setUpAll(() async {
    final loader = FontLoader('Manrope');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Manrope-$weight.ttf'));
    }
    await loader.load();
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/design_v2/source-manifest.json'),
    ) as Map<String, dynamic>;
    brandPaths = (manifest['entries'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((entry) => entry['kind'] == 'brand-svg')
        .map((entry) => entry['assetPath'] as String)
        .toList();
    canonicalFlutter = await rootBundle.loadString(
      'assets/icons/technology/flutter.svg',
    );
    compatibleFlutter = await rootBundle.loadString(
      'assets/icons/technology/flutter.render.svg',
    );
  });

  for (final configuration in [
    ('dark', StackCardTheme.dark),
    ('light', StackCardTheme.light),
  ]) {
    testWidgets(
      '${configuration.$1} runtime icons and Brand A SVG decode without labels',
      (tester) async {
        final names = {
          ...StackCardIcon.lucideNames,
          ...StackCardIcon.technologyNames,
        };
        expect(names, hasLength(23));
        expect(brandPaths, hasLength(9));
        final originalPrint = debugPrint;
        final warnings = <String>[];
        debugPrint = (message, {wrapWidth}) {
          if (message != null) warnings.add(message);
          originalPrint(message, wrapWidth: wrapWidth);
        };
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: configuration.$2,
              home: Scaffold(
                body: Wrap(
                  children: [
                    for (final name in names)
                      if (name == 'flutter')
                        RepaintBoundary(
                          key: const Key('flutter_render_probe'),
                          child: StackCardIcon(name: name, size: 300),
                        )
                      else
                        StackCardIcon(name: name),
                    for (final path in brandPaths)
                      SvgPicture.asset(
                        path,
                        width: 24,
                        height: 24,
                        excludeFromSemantics: true,
                      ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(SvgPicture), findsNWidgets(32));
          final pictures = tester
              .widgetList<SvgPicture>(find.byType(SvgPicture))
              .toList();
          final context = tester.element(find.byType(Wrap));
          await tester.runAsync(() async {
            for (final picture in pictures) {
              final bytes = await picture.bytesLoader.loadBytes(context);
              expect(bytes.lengthInBytes, greaterThan(0));
              expect(picture.excludeFromSemantics, isTrue);
            }
          });
          await tester.pumpAndSettle();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('flutter_render_probe')),
          );
          final bitmapData = await tester.runAsync(() async {
            final bitmap = await boundary.toImage();
            try {
              return await bitmap.toByteData(
                format: ui.ImageByteFormat.rawStraightRgba,
              );
            } finally {
              bitmap.dispose();
            }
          });
          expect(bitmapData, isNotNull);
          final viewBox = RegExp(r'viewBox="([^"]+)"')
              .firstMatch(canonicalFlutter)!
              .group(1)!
              .split(' ')
              .map(double.parse)
              .toList();
          final opacity = double.parse(
            RegExp(r'opacity:([\d.]+)').firstMatch(canonicalFlutter)!.group(1)!,
          );
          final scale = math.min(
            boundary.size.width / viewBox[2],
            boundary.size.height / viewBox[3],
          );
          final left = (boundary.size.width - viewBox[2] * scale) / 2;
          final top = (boundary.size.height - viewBox[3] * scale) / 2;
          for (final sample in [
            (point: const Offset(230, 350), layers: 1),
            (point: const Offset(150, 300), layers: 2),
          ]) {
            final x = (left + sample.point.dx * scale).round();
            final y = (top + sample.point.dy * scale).round();
            final offset = (y * boundary.size.width.round() + x) * 4;
            for (var channel = 0; channel < 3; channel++) {
              expect(bitmapData!.getUint8(offset + channel), closeTo(255, 1));
            }
            final expectedAlpha =
                (1 - math.pow(1 - opacity, sample.layers)) * 255;
            expect(
              bitmapData!.getUint8(offset + 3),
              closeTo(expectedAlpha, 2),
              reason: 'Parser preserves white fill and source opacity layers',
            );
          }
          expect(
            warnings.where((message) => message.contains('unhandled element')),
            isEmpty,
            reason: 'Imported SVG features must be understood by the parser',
          );
          expect(tester.takeException(), isNull);
        } finally {
          debugPrint = originalPrint;
        }
      },
    );

    for (final label in [
      '  UI Design / Firebase integration with a custom technology name  ',
      'Проектирование интерфейсов и собственная технология для портфолио',
    ]) {
      testWidgets(
        '${configuration.$1} unknown label remains complete at text 2',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(
            MaterialApp(
              theme: configuration.$2,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: StackCardTechnologyBadge(label: label),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(label), findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(paragraph.maxLines, isNull);
          final semantics = tester.ensureSemantics();
          try {
            expect(
              tester.getSemantics(find.bySemanticsLabel(label)),
              isSemantics(label: label, isButton: false, hasTapAction: false),
            );
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }

    testWidgets(
      '${configuration.$1} +N has a full label and one keyboard action',
      (tester) async {
        var opens = 0;
        const label = 'Показать ещё 2 технологии проекта';
        await tester.pumpWidget(
          MaterialApp(
            theme: configuration.$2,
            home: Scaffold(
              body: Center(
                child: StackCardMoreTechnologies(
                  count: 2,
                  label: label,
                  onPressed: () => opens++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final semantics = tester.ensureSemantics();
        try {
          final button = find.bySemanticsLabel(label);
          expect(button, findsOneWidget);
          expect(tester.getRect(button).width, greaterThanOrEqualTo(48));
          expect(tester.getRect(button).height, greaterThanOrEqualTo(48));
          expect(
            tester.getSemantics(button),
            isSemantics(
              label: label,
              isButton: true,
              isEnabled: true,
              hasTapAction: true,
            ),
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(opens, 1);
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pumpAndSettle();
          expect(opens, 2);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      '${configuration.$1} action icon receives foreground without tinting brands',
      (tester) async {
        final theme = configuration.$2;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: [
                  StackCardButton(
                    label: 'Copy document',
                    primary: true,
                    iconWidget: const StackCardIcon(name: 'copy'),
                    onPressed: () {},
                  ),
                  const StackCardTechnologyBadge(label: 'Flutter'),
                  const StackCardTechnologyBadge(label: 'Dart'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final colors = theme.extension<StackCardColors>()!;
        final actionSvg = tester.widget<SvgPicture>(
          find.descendant(
            of: find.byType(StackCardButton),
            matching: find.byType(SvgPicture),
          ),
        );
        expect(
          actionSvg.colorFilter,
          ColorFilter.mode(colors.onPrimary, BlendMode.srcIn),
        );
        for (final brand in tester.widgetList<SvgPicture>(
          find.descendant(
            of: find.byType(StackCardTechnologyBadge),
            matching: find.byType(SvgPicture),
          ),
        )) {
          expect(brand.colorFilter, isNull);
          final loader = brand.bytesLoader as SvgAssetLoader;
          expect(loader.colorMapper, isNull);
          if (loader.assetName.contains('flutter')) {
            expect(
              loader.assetName,
              'assets/icons/technology/flutter.render.svg',
              reason: 'The runtime uses parser-compatible source colors',
            );
          }
        }
        final css = RegExp(r'\.cls-1\{([^}]+)\}')
            .firstMatch(canonicalFlutter)!
            .group(1)!;
        final declarations = {
          for (final item in css.split(';').where((item) => item.contains(':')))
            item.split(':').first: item.split(':').last,
        };
        final originalPoints = RegExp(r'points="([^"]+)"')
            .allMatches(canonicalFlutter)
            .map((match) => match.group(1))
            .toList();
        final compatiblePolygons = RegExp(r'<polygon\b([^>]+)')
            .allMatches(compatibleFlutter)
            .map((match) => match.group(1)!)
            .toList();
        expect(compatiblePolygons, hasLength(originalPoints.length));
        expect(compatibleFlutter, isNot(contains('<style')));
        for (var index = 0; index < compatiblePolygons.length; index++) {
          final attributes = {
            for (final attribute in RegExp(
              r'([\w-]+)="([^"]*)"',
            ).allMatches(compatiblePolygons[index]))
              attribute.group(1)!: attribute.group(2)!,
          };
          expect(attributes['points'], originalPoints[index]);
          expect(attributes['fill'], declarations['fill']);
          expect(attributes['opacity'], declarations['opacity']);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
