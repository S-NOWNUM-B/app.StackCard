import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Малые экраны для проверки диалогов: портрет 320x568 и landscape.
const dialogTextFitSizes = [Size(320, 568), Size(568, 320)];

void useDialogTextFitSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Каждый текст диалога имеет ненулевую высоту и целиком проходит через
/// видимую область прокрутки: верх — в начале, низ — в конце.
Future<void> expectDialogTextScrollable(
  WidgetTester tester,
  List<String> texts,
) async {
  final dialog = find.byType(AlertDialog);
  expect(dialog, findsOneWidget);
  final scrollable = find
      .descendant(of: dialog, matching: find.byType(Scrollable))
      .first;
  final viewport = tester.getRect(scrollable);
  expect(viewport.height, greaterThan(0));
  for (final text in texts) {
    final finder = find.descendant(of: dialog, matching: find.text(text));
    expect(finder, findsOneWidget, reason: text);
    expect(tester.getSize(finder).height, greaterThan(0), reason: text);
    final position = tester.state<ScrollableState>(scrollable).position;
    // Начало текста: прокручиваем так, чтобы верх попал в область диалога.
    position.jumpTo(
      (position.pixels + tester.getRect(finder).top - viewport.top).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    await tester.pump();
    expect(
      tester.getRect(finder).top,
      greaterThanOrEqualTo(viewport.top - 0.5),
      reason: text,
    );
    expect(tester.getRect(finder).top, lessThan(viewport.bottom), reason: text);
    // Конец текста: низ тоже достижим прокруткой, без обрезки.
    position.jumpTo(
      (position.pixels + tester.getRect(finder).bottom - viewport.bottom).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    await tester.pump();
    expect(
      tester.getRect(finder).bottom,
      lessThanOrEqualTo(viewport.bottom + 0.5),
      reason: text,
    );
    expect(
      tester.getRect(finder).bottom,
      greaterThan(viewport.top),
      reason: text,
    );
  }
  expect(tester.takeException(), isNull);
}
