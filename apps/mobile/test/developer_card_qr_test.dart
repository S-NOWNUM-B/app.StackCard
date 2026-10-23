import 'package:app_stackcard/features/portfolio_draft/presentation/developer_card_qr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'QR skips parent repaint, updates URL and relayouts at smaller width',
    (tester) async {
      Future<void> show(String id, {double width = 280}) => tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: width,
              child: DeveloperCardQr(
                url: Uri.parse('https://example.com/d/$id'),
              ),
            ),
          ),
        ),
      );
      CustomPainter painter() => tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byKey(const Key('developerCard.qr')),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
      await show('a' * 32);
      final first = painter();
      await show('a' * 32);
      expect(painter().shouldRepaint(first), isFalse);
      final beforeChange = painter();
      await show('b' * 32);
      expect(painter().shouldRepaint(beforeChange), isTrue);
      final beforeResize = painter();
      final originalSize = tester.getSize(
        find.byKey(const Key('developerCard.qr')),
      );
      await show('b' * 32, width: 180);
      expect(
        tester.getSize(find.byKey(const Key('developerCard.qr'))).width,
        lessThan(originalSize.width),
      );
      expect(painter().shouldRepaint(beforeResize), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
