import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/home/home_screen.dart';
import 'package:app_stackcard/features/projects/projects.dart';
import 'package:app_stackcard/features/portfolio_draft/data/asset_portfolio_pdf_generator.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/developer_card_qr.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'fixture.dart';

/// Запускается явно через flutter test tool/performance/benchmark.dart.
/// Wall clock в debug flutter_tester — диагностика CPU, не native frame timing.
void main() {
  final workspace = performanceWorkspace();
  final results = <String, Object?>{
    'environment':
        'flutter_tester debug, ${Platform.operatingSystem}, ${Platform.version}',
    'fixture': {
      'projects': 200,
      'technologiesPerProject': 20,
      'skills': 200,
      'experience': 30,
      'education': 20,
      'links': 10,
      'documents': 21,
    },
  };
  final output = const String.fromEnvironment('PERFORMANCE_OUTPUT');

  testWidgets('Phase 16 repeatable local CPU diagnostics', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    expect(validatePortfolioContent(workspace), isEmpty);
    final font = FontLoader('Manrope');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      font.addFont(rootBundle.load('assets/fonts/Manrope-$weight.ttf'));
    }
    await font.load();

    for (final length in [60, 1024]) {
      final prefix = 'https://example.com/';
      final suffix = '/d/0123456789abcdef0123456789abcdef';
      final url = Uri.parse(
        '$prefix${'a' * (length - prefix.length - suffix.length)}$suffix',
      );
      Future<void> rebuild() =>
          tester.pumpWidget(_app(Center(child: DeveloperCardQr(url: url))));
      await rebuild();
      final samples = <double>[];
      var repaints = 0;
      var previous = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byKey(const Key('developerCard.qr')),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
      for (var i = 0; i < 25; i++) {
        final watch = Stopwatch()..start();
        await rebuild();
        watch.stop();
        samples.add(watch.elapsedMicroseconds / 1000);
        final painter = tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byKey(const Key('developerCard.qr')),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!;
        if (!identical(previous, painter) && painter.shouldRepaint(previous)) {
          repaints++;
        }
        previous = painter;
      }
      results['qr${length}ParentRebuild'] = {
        ..._stats(samples),
        'repaintsRequested': repaints,
      };
    }
    final repository = MemoryPortfolioDraftRepository();
    await repository.save(
      workspace,
      expectedRevision: 0,
      notes: 'PRIVATE_NOTES',
    );
    for (final (name, screen) in <(String, Widget)>[
      ('home', const HomeScreen()),
      ('library', const ProjectsScreen()),
      ('editor', const MainPortfolioEditorScreen()),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      final container = ProviderContainer(
        overrides: [
          portfolioDraftRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final watch = Stopwatch()..start();
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: _app(screen)),
      );
      await tester.pumpAndSettle();
      watch.stop();
      results[name] = {
        'mountWallMs': watch.elapsedMicroseconds / 1000,
        'mountedElements': tester.allElements.length,
        'processRssBytes': ProcessInfo.currentRss,
      };
      expect(find.textContaining('LEGACY_PRIVATE'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    }
    await tester.runAsync(() async {
      final avatar = Uint8List.fromList(
        image.encodeJpg(image.Image(width: 512, height: 512)),
      );
      final saved = resolvedMainPortfolioContent(workspace)!;
      final generator = AssetPortfolioPdfGenerator();
      final samples = <double>[];
      var size = 0;
      for (var i = 0; i < 3; i++) {
        final watch = Stopwatch()..start();
        final bytes = await generator.generate(saved, avatarBytes: avatar);
        watch.stop();
        expect(isPortfolioPdfBytes(bytes), isTrue);
        size = bytes.length;
        samples.add(watch.elapsedMicroseconds / 1000);
        if (i == 2 && output.isNotEmpty) {
          await File('$output.pdf').writeAsBytes(bytes);
        }
      }
      results['pdf'] = {
        ..._stats(samples),
        'bytes': size,
        'avatar': '512x512 JPEG',
      };
      if (output.isNotEmpty) {
        await File(output)
            .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
        await File('$output.workspace.json')
            .writeAsString(jsonEncode(encodePortfolioContent(workspace)));
      }
    });
    // ignore: avoid_print
    print('PERFORMANCE ${jsonEncode(results)}');
  });
}

Map<String, Object> _stats(List<double> samples) {
  final sorted = [...samples]..sort();
  return {
    'samplesMs': samples,
    'medianMs': sorted[sorted.length ~/ 2],
    'p95Ms': sorted[(sorted.length * .95).ceil() - 1],
  };
}

Widget _app(Widget home) => MaterialApp(
  theme: StackCardTheme.light,
  locale: const Locale('ru'),
  localizationsDelegates: const [
    AppStrings.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppStrings.supportedLocales,
  home: Scaffold(body: home),
);
