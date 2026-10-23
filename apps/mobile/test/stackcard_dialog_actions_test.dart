import 'package:app_stackcard/core/theme/stackcard_colors.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/shared/widgets/stackcard_dialog_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (width, scale) in [(600.0, 1.0), (288.0, 2.0)]) {
    testWidgets('Dialog actions keep order and alignment at $width/$scale', (
      tester,
    ) async {
      var cancelled = 0;
      var confirmed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: StackCardTheme.light,
          home: Scaffold(
            body: Center(
              child: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: TextScaler.linear(scale),
                ),
                child: SizedBox(
                  width: width,
                  child: StackCardDialogActions(
                    onCancel: () => cancelled++,
                    onConfirm: () => confirmed++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final buttons = find.byType(FilledButton);
      final cancel = buttons.at(0);
      final confirm = buttons.at(1);
      final group = tester.getRect(find.byType(StackCardDialogActions));
      final cancelRect = tester.getRect(cancel);
      final confirmRect = tester.getRect(confirm);
      expect(find.text('Отмена'), findsOneWidget);
      expect(find.text('Подтвердить'), findsOneWidget);
      expect(confirmRect.right, closeTo(group.right - 4, 0.01));
      if (scale == 1) {
        expect(cancelRect.top, confirmRect.top);
        expect(cancelRect.right, lessThan(confirmRect.left));
        expect(cancelRect.width, closeTo(confirmRect.width, 0.01));
      } else {
        expect(cancelRect.bottom, lessThan(confirmRect.top));
        expect(cancelRect.right, closeTo(confirmRect.right, 0.01));
      }
      final colors = tester.element(cancel).colors;
      expect(
        tester.widget<FilledButton>(cancel).style!.side!.resolve({})!.color,
        colors.primaryOutline,
      );
      expect(
        tester
            .widget<FilledButton>(confirm)
            .style!
            .backgroundColor!
            .resolve({}),
        colors.primary,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(cancelled, 1);
      expect(confirmed, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(confirmed, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
