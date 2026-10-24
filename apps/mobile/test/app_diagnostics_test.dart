import 'dart:async';

import 'package:app_stackcard/core/diagnostics/app_diagnostics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_stackcard/main.dart';

class _Sink implements DiagnosticsSink {
  final calls = <String>[];
  final reports = <String>[];
  bool fail = false;
  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    calls.add('enabled:$enabled');
    if (fail) throw StateError('private-token');
  }

  @override
  Future<void> deleteUnsentReports() async => calls.add('delete');
  @override
  Future<void> record(
    DiagnosticCode code,
    StackTrace stack, {
    required bool fatal,
  }) async {
    reports.add('${code.name}:$fatal:$stack');
    if (fail) throw StateError('private-token');
  }
}

void main() {
  testWidgets(
    'settings requires explicit consent and can turn reporting off again',
    (tester) async {
      final sink = _Sink();
      var consent = false;
      final diagnostics = AppDiagnostics(
        sink: sink,
        readConsent: () async => consent,
        writeConsent: (value) async {
          consent = value;
        },
      );
      await diagnostics.initialize();
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/settings/appearance',
          providerOverrides: [
            appDiagnosticsProvider.overrideWithValue(diagnostics),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('settings.diagnostics'));
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(consent, isTrue);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(consent, isFalse);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.pumpWidget(const SizedBox());
      diagnostics.dispose();
    },
  );
  test(
    'default opt-out deletes pending reports; opt-in clears before enable',
    () async {
      final sink = _Sink();
      var consent = false;
      final diagnostics = AppDiagnostics(
        sink: sink,
        readConsent: () async => consent,
        writeConsent: (value) async {
          consent = value;
        },
      );
      await diagnostics.initialize();
      await diagnostics.report(
        DiagnosticCode.unhandledAsync,
        StackTrace.current,
      );
      expect(sink.calls, ['enabled:false', 'delete']);
      expect(sink.reports, isEmpty);
      await diagnostics.setEnabled(true);
      expect(consent, isTrue);
      expect(sink.calls.skip(2), ['enabled:false', 'delete', 'enabled:true']);
      await diagnostics.report(
        DiagnosticCode.unhandledAsync,
        StackTrace.current,
        fatal: true,
      );
      expect(sink.reports.single, startsWith('unhandledAsync:true:'));
      await diagnostics.setEnabled(false);
      await diagnostics.report(DiagnosticCode.acceptance, StackTrace.current);
      expect(consent, isFalse);
      expect(sink.reports.length, 1);
      diagnostics.dispose();
    },
  );

  test('privacy filter excludes private text, SDK frames, file URLs and forged source', () {
    final stack = diagnosticStack(
      StackTrace.fromString('''
#0 uid-token-private-contact (package:app_stackcard/main.dart:12:3)
#1 private-note (file:///Users/private-name/secret.dart:12:3)
#2 token (package:firebase_auth/token.dart:4:1)
#3 email (package:app_stackcard/owner_uid_private.dart:1:1)
#4 contact (https://example.com/private?token=secret:12:3)
'''),
    ).toString();
    expect(stack, '#0 StackCard.frame (package:app_stackcard/main.dart:12:3)');
    expect(
      diagnosticStack(StackTrace.fromString('private-note')).toString(),
      contains('StackCard.redacted'),
    );
  });

  test('consent read/write failures fail closed and concurrent toggle cannot reopen collection', () async {
    final sink = _Sink();
    final pending = Completer<void>();
    var writes = 0;
    final diagnostics = AppDiagnostics(
      sink: sink,
      readConsent: () async => throw StateError('private'),
      writeConsent: (_) async {
        writes++;
        await pending.future;
        throw StateError('private');
      },
    );
    await diagnostics.initialize();
    expect(diagnostics.enabled, isFalse);
    expect(diagnostics.failed, isTrue);
    final enabling = diagnostics.setEnabled(true);
    await Future<void>.delayed(Duration.zero);
    await diagnostics.setEnabled(false);
    await diagnostics.report(DiagnosticCode.acceptance, StackTrace.current);
    expect(writes, 1);
    expect(sink.reports, isEmpty);
    pending.complete();
    await enabling;
    expect(diagnostics.enabled, isFalse);
    expect(diagnostics.failed, isTrue);
    expect(sink.calls.last, 'delete');
    diagnostics.dispose();
  });

  test('sink failure does not recurse and report count is bounded', () async {
    final sink = _Sink();
    final diagnostics = AppDiagnostics(
      sink: sink,
      readConsent: () async => true,
      writeConsent: (_) async {},
    );
    await diagnostics.initialize();
    sink.fail = true;
    for (var index = 0; index < 25; index++) {
      await diagnostics.report(DiagnosticCode.acceptance, StackTrace.current);
    }
    expect(sink.reports.length, 20);
    diagnostics.dispose();
    await diagnostics.report(DiagnosticCode.acceptance, StackTrace.current);
    expect(sink.reports.length, 20);
  });

  test('handler forwards only sanitized report and restores previous Flutter handler', () async {
    final sink = _Sink();
    final diagnostics = AppDiagnostics(
      sink: sink,
      readConsent: () async => true,
      writeConsent: (_) async {},
    );
    await diagnostics.initialize();
    final previous = FlutterError.onError;
    FlutterError.onError = (_) {};
    final debugHandler = FlutterError.onError;
    diagnostics.installErrorHandlers();
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('UID contact token private-note'),
        stack: StackTrace.fromString(
          '#0 private (package:app_stackcard/main.dart:4:2)',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      sink.reports.single,
      'flutterFramework:false:#0 StackCard.frame (package:app_stackcard/main.dart:4:2)',
    );
    diagnostics.dispose();
    expect(FlutterError.onError, debugHandler);
    FlutterError.onError = previous;
  });
}
