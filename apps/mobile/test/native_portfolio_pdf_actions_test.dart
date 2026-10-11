import 'dart:async';
import 'dart:convert';

import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_pdf.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/native_document_link_actions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('stackcard/document_links');
  const actions = NativeDocumentLinkActions();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final bytes = Uint8List.fromList(ascii.encode('%PDF-1.4\nfixture'));
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Matcher failure(PortfolioPdfFailureKind kind) =>
      isA<PortfolioPdfFailure>().having((error) => error.kind, 'kind', kind);

  test('save forwards actual bytes and returns only confirmed save', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return true;
    });
    expect(await actions.savePdf(bytes), isTrue);
    expect(captured?.method, 'savePdf');
    expect(captured?.arguments, {
      'bytes': bytes,
      'filename': 'stackcard-portfolio.pdf',
    });
  });

  test(
    'picker cancellation is false and never reported as successful save',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      expect(await actions.savePdf(bytes), isFalse);
    },
  );

  for (final filename in [
    '../portfolio.pdf',
    '/portfolio.pdf',
    'x.txt',
    'x.pdf\n',
    'x/y.pdf',
  ]) {
    test('rejects unsafe filename $filename before native IO', () async {
      var called = false;
      messenger.setMockMethodCallHandler(channel, (_) async {
        called = true;
        return true;
      });
      await expectLater(
        actions.savePdf(bytes, filename: filename),
        throwsA(failure(PortfolioPdfFailureKind.invalidData)),
      );
      expect(called, isFalse);
    });
  }

  test('rejects non-PDF and oversized payloads before native IO', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (_) async {
      called = true;
      return true;
    });
    await expectLater(
      actions.savePdf(Uint8List(5)),
      throwsA(failure(PortfolioPdfFailureKind.invalidData)),
    );
    final oversized = Uint8List(portfolioPdfMaximumBytes + 1)
      ..setRange(0, 5, bytes);
    await expectLater(
      actions.savePdf(oversized),
      throwsA(failure(PortfolioPdfFailureKind.invalidData)),
    );
    expect(called, isFalse);
  });

  test(
    'missing handler or invalid native response does not fabricate save',
    () async {
      await expectLater(
        actions.savePdf(bytes),
        throwsA(failure(PortfolioPdfFailureKind.unavailable)),
      );
      for (final response in [
        null,
        'true',
        {'saved': true},
      ]) {
        messenger.setMockMethodCallHandler(channel, (_) async => response);
        await expectLater(
          actions.savePdf(bytes),
          throwsA(failure(PortfolioPdfFailureKind.unavailable)),
        );
      }
    },
  );

  testWidgets('file picker remains pending beyond the URL action timeout', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (_) => pending.future);
    var completed = false;
    final saving = actions.savePdf(bytes).then((saved) {
      completed = true;
      return saved;
    });
    await tester.pump(const Duration(seconds: 45));
    expect(completed, isFalse);
    pending.complete(false);
    await tester.pump();
    expect(await saving, isFalse);
  });
}
