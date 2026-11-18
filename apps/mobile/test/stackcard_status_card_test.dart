import 'package:app_stackcard/core/theme/stackcard_colors.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/shared/widgets/stackcard_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  StackCardStatusTone tone,
  ThemeData theme, {
  String? title,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme,
    home: Scaffold(
      body: StackCardStatusCard(title: title, message: 'Сообщение', tone: tone),
    ),
  ),
);

void main() {
  for (final entry in {
    'light': (StackCardTheme.light, StackCardColors.light),
    'dark': (StackCardTheme.dark, StackCardColors.dark),
  }.entries) {
    testWidgets(
      'Error tone uses the error color and its own icon in ${entry.key}',
      (tester) async {
        final (theme, colors) = entry.value;
        await _pump(tester, StackCardStatusTone.error, theme);
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.icon, Icons.error_outline_rounded);
        expect(icon.color, colors.error);
        final text = tester.widget<Text>(find.text('Сообщение'));
        expect(text.style?.color, colors.error);
      },
    );

    testWidgets('Tones differ by icon, not only by color in ${entry.key}', (
      tester,
    ) async {
      final icons = <IconData?>[];
      for (final tone in StackCardStatusTone.values) {
        await _pump(tester, tone, entry.value.$1, title: 'Заголовок');
        icons.add(tester.widget<Icon>(find.byType(Icon)).icon);
      }
      expect(icons.toSet(), hasLength(StackCardStatusTone.values.length));
    });
  }
}
