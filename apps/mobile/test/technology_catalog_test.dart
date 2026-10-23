import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/shared/widgets/stackcard_icon.dart';
import 'package:app_stackcard/shared/widgets/technology_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lookup ignores case, spaces, dots and resolves aliases', () {
    expect(findTechnology('next.js')?.title, 'Next.js');
    expect(findTechnology('NextJS')?.title, 'Next.js');
    expect(findTechnology('postgres')?.title, 'PostgreSQL');
    expect(findTechnology('spring')?.title, 'Spring Boot');
    expect(findTechnology('k8s')?.title, 'Kubernetes');
    expect(findTechnology('Flutter')?.slug, isNull);
    expect(findTechnology('Моя внутренняя библиотека'), isNull);
    expect(findTechnology('  '), isNull);
  });

  test('suggestions rank prefix matches and skip existing values', () {
    expect(technologySuggestions('ko').first.title, 'Kotlin');
    expect(technologySuggestions('post').first.title, 'PostgreSQL');
    expect(
      technologySuggestions('ko', exclude: ['kotlin']).map((i) => i.title),
      isNot(contains('Kotlin')),
    );
    expect(technologySuggestions(''), isEmpty);
    expect(technologySuggestions('a'), hasLength(6));
  });

  test('every catalog icon has a pinned SVG and manifest entry', () {
    final manifest = jsonDecode(
      File('assets/icons/technology/SIMPLE-ICONS-MANIFEST.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final slugs = {
      for (final icon in manifest['icons'] as List) icon['slug'] as String,
    };
    final titles = <String>{};
    for (final info in technologyCatalog) {
      expect(titles.add(info.title.toLowerCase()), isTrue, reason: info.title);
      final slug = info.slug;
      if (slug == null) {
        expect(
          StackCardIcon.technologyNames,
          contains(info.title.toLowerCase()),
        );
      } else {
        expect(slugs, contains(slug));
        expect(
          File('assets/icons/technology/simple-icons/$slug.svg').existsSync(),
          isTrue,
          reason: slug,
        );
      }
    }
  });

  testWidgets('known technology renders its SVG, unknown a neutral folder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StackCardTheme.light,
        home: const Scaffold(
          body: Row(
            children: [
              StackCardTechnologyIcon(label: 'Kotlin'),
              StackCardTechnologyIcon(label: 'Своя технология'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final paths = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((picture) => (picture.bytesLoader as SvgAssetLoader).assetName)
        .toList();
    expect(paths, [
      'assets/icons/technology/simple-icons/kotlin.svg',
      'assets/icons/lucide/folder.svg',
    ]);
    expect(tester.takeException(), isNull);
  });
}
