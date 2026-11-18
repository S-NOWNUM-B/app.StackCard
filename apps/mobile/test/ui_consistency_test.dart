import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Theme segments keep each label on one line at 320dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const StackCardApp(initialLocation: '/settings/appearance'),
    );
    await tester.pumpAndSettle();
    for (final key in ['system', 'light', 'dark']) {
      final label = find.byKey(Key('settings.theme.$key'));
      expect(label, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(paragraph.didExceedMaxLines, isFalse, reason: key);
      expect(paragraph.size.height, lessThan(26), reason: key);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Projects entry buttons share one height on a 411dp phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const StackCardApp(initialLocation: '/projects'));
    await tester.pumpAndSettle();
    final vacancy = tester.getSize(
      find.byKey(const ValueKey('projects.vacancy')),
    );
    final dna = tester.getSize(find.byKey(const ValueKey('projects.stackDna')));
    expect(vacancy.height, dna.height);
    expect(find.text('Подбор под вакансию'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'Unavailable publication explains the cause and has no trailing dot',
    () {
      const strings = AppStrings(Locale('ru'));
      for (final key in [
        'documentPublication.unconfigured',
        'documentPublication.error.configurationRequired',
        'documentEditor.publishUnavailable',
      ]) {
        final text = strings.tr(key);
        expect(text.trimRight().endsWith('.'), isFalse, reason: key);
        expect(text, contains('Публикация недоступна:'), reason: key);
      }
    },
  );
}
